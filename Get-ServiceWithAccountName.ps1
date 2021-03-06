﻿<#
.SYNOPSIS
	Find Services using a specific account name on Servers in Microsoft 
	Active Directory.
.DESCRIPTION
	By default, builds a list of all computers where "Server" is in the 
	OperatingSystem property unless the ComputerName or InputFile 
	parameter is used.
	
	Process each server looking for Services using a specific StartName.
	
	Builds a list of computer names, Service names, service display names and service start names.
	
	Display the matching results on the console and creates two text files, by default, 
	in the folder where the script is run.
	
	Optionally, can specify the output folder.
	
	Unless the InputFile parameter is used, needs the ActiveDirectory module.
	
	The script has been tested with PowerShell versions 2, 3, 4, 5, and 5.1.
	The script has been tested with Microsoft Windows Server 2008 R2, 2012, 
	2012 R2, and 2016 and Windows 10 Creators Update.
.PARAMETER AccountName
	Account name used for the service "log on".
	Script surrounds AccountName with "*".
	
	For example, if ctxadmin is entered, the script uses "*ctxadmin*".
	
	This allows the script to find Services where the StartName property is:
		ctxadmin@domain.com
		Domain\ctxadmin
		Domain.com\ctxadmin
	
	Side effect: Will also find Services with StartName like "This is the ctxadmin account"
	
	This is a Required parameter.
	Alias is AN
.PARAMETER LiteralAccountName
	Account name used for the service "log on".
	Unlike AccountName, the value of LiteralAccountName is used exactly as it is typed.
	
	For example, if ctxadmin is entered, the script uses "ctxadmin".
	
	This is a Required parameter.
	Alias is LAN
.PARAMETER ComputerName
	Computer name used to restrict the computer search.
	Script surrounds ComputerName with "*".
	
	For example, if "PVS" is entered, the script uses "*PVS*".
	
	This allows the script to reduce the number of servers searched.
	
	If both ComputerName and InputFile are used, ComputerName is used to filter
	the list of computer names read from InputFile.
	
	Alias is CN
.PARAMETER InputFile
	Specifies the optional input file containing computer account names to search.
	
	Computer account names can be either the NetBIOS or Fully Qualified Domain Name.
	
	ServerName and ServerName.domain.tld are both valid.
	
	If both ComputerName and InputFile are used, ComputerName is used to filter
	the list of computer names read from InputFile.
	
	The computer names contained in the input file are not validated.
	
	Using this parameter causes the script to not check for or load the ActiveDirectory module.
	
	Alias is IF
.PARAMETER OrganizationalUnit
	Restricts the retrieval of computer accounts to a specific OU tree. 
	Must be entered in Distinguished Name format. i.e. OU=XenDesktop,DC=domain,DC=tld. 
	
	The script retrieves computer accounts from the top level OU and all sub-level OUs.
	
	Alias OU
.PARAMETER Folder
	Specifies the optional output folder to save the output reports. 
.EXAMPLE
	PS C:\PSScript > .\Get-ServiceWithAccountName.ps1 -AccountName ctxadmin
	
	The script will change "ctxadmin" to "*ctxadmin*" and will seach for all 
	services using a StartName that contains "ctxadmin".
	
.EXAMPLE
	PS C:\PSScript > .\Get-ServiceWithAccountName.ps1 -AN svc_acct
	
	The script will change "svc_acct" to "*svc_acct*" and will seach for all 
	services using a StartName that contains "svc_acct".
	
.EXAMPLE
	PS C:\PSScript > .\Get-ServiceWithAccountName.ps1 -LiteralAccountName sql@domain.tld
	
	The script will make no changes to the LiteralAccountName and will seach for all 
	services using a StartName of "sql@domain.tld".
	
	This means, the script will not find services using a StartName of domain\sql or
	domain.tld\sql.
	
.EXAMPLE
	PS C:\PSScript > .\Get-ServiceWithAccountName.ps1 -AccountName svc_acct -ComputerName PVS
	
	The script will change "svc_acct" to "*svc_acct*" and will seach for all 
	services using a StartName that contains "svc_acct".

	If InputFIle is not used, the script will only search computers with "PVS" 
	in the DNSHostName.
	
	If InputFile is used, the script will only search computers with "PVS" in 
	the entries contained in the file.

.EXAMPLE
	PS C:\PSScript > .\Get-ServiceWithAccountName.ps1 -AccountName ctxadmin -Folder \\FileServer\ShareName
	
	The script will change "ctxadmin" to "*ctxadmin*".
	Output file will be saved in the path \\FileServer\ShareName
	
.EXAMPLE
	PS C:\PSScript > .\Get-ServiceWithAccountName.ps1 -AccountName svc_acct -ComputerName SQL -InputFile c:\Scripts\computers.txt
	
	The script will change "svc_acct" to "*svc_acct*" and will seach for all 
	services using a StartName that contains "svc_acct".

	The script will only search computers with "SQL" in the file computers.txt.
	
	InputFile causes the script to not check for or use the ActiveDirectory module.

.INPUTS
	None.  You cannot pipe objects to this script.
.OUTPUTS
	No objects are output from this script.  This script creates two texts files.
.NOTES
	NAME: Get-ServiceWithAccountName.ps1
	VERSION: 1.00
	AUTHOR: Carl Webster
	LASTEDIT: May 14, 2017
#>


#Created by Carl Webster, CTP 30-Mar-2017
#webster@carlwebster.com
#@carlwebster on Twitter
#http://www.CarlWebster.com

[CmdletBinding(SupportsShouldProcess = $False, ConfirmImpact = "None", DefaultParameterSetName = "AccountName") ]

Param(
	[parameter(ParameterSetName="AccountName",Mandatory=$True)] 
	[Alias("AN")]
	[ValidateNotNullOrEmpty()]
	[string]$AccountName,
	
	[parameter(ParameterSetName="LiteralAccountName",Mandatory=$True)] 
	[Alias("LAN")]
	[ValidateNotNullOrEmpty()]
	[string]$LiteralAccountName,

	[parameter(Mandatory=$False)] 
	[Alias("CN")]
	[string]$ComputerName,
	
	[parameter(Mandatory=$False)] 
	[Alias("IF")]
	[string]$InputFile="",
	
	[parameter(Mandatory=$False)] 
	[Alias("OU")]
	[string]$OrganizationalUnit="",
	
	[parameter(Mandatory=$False)] 
	[string]$Folder=""
	
	)

Set-StrictMode -Version 2

Write-Host "$(Get-Date): Setting up script"

If(![String]::IsNullOrEmpty($InputFile))
{
	Write-Host "$(Get-Date): Validating input file"
	If(!(Test-Path $InputFile))
	{
		Write-Error "Input file specified but $InputFile does not exist. Script cannot continue."
		Exit
	}
}

If($Folder -ne "")
{
	Write-Host "$(Get-Date): Testing folder path"
	#does it exist
	If(Test-Path $Folder -EA 0)
	{
		#it exists, now check to see if it is a folder and not a file
		If(Test-Path $Folder -pathType Container -EA 0)
		{
			#it exists and it is a folder
			Write-Host "$(Get-Date): Folder path $Folder exists and is a folder"
		}
		Else
		{
			#it exists but it is a file not a folder
			Write-Error "Folder $Folder is a file, not a folder. Script cannot continue"
			Exit
		}
	}
	Else
	{
		#does not exist
		Write-Error "Folder $Folder does not exist.  Script cannot continue"
		Exit
	}
}

#test to see if OrganizationalUnit is valid
If(![String]::IsNullOrEmpty($OrganizationalUnit))
{
	Write-Host "$(Get-Date): Validating Organnization Unit"
	try 
	{
		$results = Get-ADOrganizationalUnit -Identity $OrganizationalUnit
	} 
	
	catch
	{
		#does not exist
		Write-Error "Organization Unit $OrganizationalUnit does not exist.`n`nScript cannot continue`n`n"
		Exit
	}	
}

If($Folder -eq "")
{
	$pwdpath = $pwd.Path
}
Else
{
	$pwdpath = $Folder
}

If($pwdpath.EndsWith("\"))
{
	#remove the trailing \
	$pwdpath = $pwdpath.SubString(0, ($pwdpath.Length - 1))
}

Function Check-LoadedModule
#Function created by Jeff Wouters
#@JeffWouters on Twitter
#modified by Michael B. Smith to handle when the module doesn't exist on server
#modified by @andyjmorgan
#bug fixed by @schose
#bug fixed by Peter Bosen
#This Function handles all three scenarios:
#
# 1. Module is already imported into current session
# 2. Module is not already imported into current session, it does exists on the server and is imported
# 3. Module does not exist on the server

{
	Param([parameter(Mandatory = $True)][alias("Module")][string]$ModuleName)
	#following line changed at the recommendation of @andyjmorgan
	$LoadedModules = Get-Module |% { $_.Name.ToString() }
	#bug reported on 21-JAN-2013 by @schose 
	
	[string]$ModuleFound = ($LoadedModules -like "*$ModuleName*")
	If($ModuleFound -ne $ModuleName) 
	{
		$module = Import-Module -Name $ModuleName -PassThru -EA 0
		If($module -and $?)
		{
			# module imported properly
			Return $True
		}
		Else
		{
			# module import failed
			Return $False
		}
	}
	Else
	{
		#module already imported into current session
		Return $True
	}
}

Function ProcessComputer 
{
	Param([string]$TmpComputerName)
	
	If(Test-Connection -ComputerName $TmpComputerName -quiet -EA 0)
	{
		If(![String]::IsNullOrEmpty($AccountName))
		{
			$Results = Get-WmiObject -ComputerName $TmpComputerName Win32_Service -EA 0 | Where-Object {$_.StartName -like $testname} | Select SystemName, Name, DisplayName, StartName
		}
		ElseIf(![String]::IsNullOrEmpty($LiteralAccountName))
		{
			$Results = Get-WmiObject -ComputerName $TmpComputerName Win32_Service -EA 0 | Where-Object {$_.StartName -eq $testname} | Select SystemName, Name, DisplayName, StartName
		}
		
		If($? -and $Null -ne $Results)
		{
			Write-Host "`tFound a match"
			$Script:AllMatches += $Results
		}
	}
	Else
	{
		Write-Host "`tComputer $($TmpComputerName) is not online"
		Out-File -FilePath $Filename2 -Append -InputObject "Computer $($TmpComputerName) was not online $(Get-Date)"
	}
}

#only check for the ActiveDirectory module if an InputFile was not entered
If([String]::IsNullOrEmpty($InputFile) -and !(Check-LoadedModule "ActiveDirectory"))
{
	Write-Host "Unable to run script, no ActiveDirectory module"
	Exit
}

[string]$Script:FileName = "$($pwdpath)\ServersWithServiceAccount.txt"
[string]$Script:FileName2 = "$($pwdpath)\ServersWithServiceAccountErrors.txt"

If(![String]::IsNullOrEmpty($ComputerName) -and [String]::IsNullOrEmpty($InputFile))
{
	#computer name but no input file
	Write-Host "$(Get-Date): Retrieving list of computers from Active Directory"
	$testname = "*$($ComputerName)*"
	If(![String]::IsNullOrEmpty($OrganizationalUnit))
	{
		$Computers = Get-AdComputer -filter {DNSHostName -like $testname} -SearchBase $OrganizationalUnit -SearchScope Subtree -properties DNSHostName, Name -EA 0 | Sort Name
	}
	Else
	{
		$Computers = Get-AdComputer -filter {DNSHostName -like $testname} -properties DNSHostName, Name -EA 0 | Sort Name
	}
}
ElseIf([String]::IsNullOrEmpty($ComputerName) -and ![String]::IsNullOrEmpty($InputFile))
{
	#input file but no computer name
	Write-Host "$(Get-Date): Retrieving list of computers from Input File"
	$Computers = Get-Content $InputFile
}
ElseIf(![String]::IsNullOrEmpty($ComputerName) -and ![String]::IsNullOrEmpty($InputFile))
{
	#both computer name and input file
	Write-Host "$(Get-Date): Retrieving list of computers from Input File"
	$testname = "*$($ComputerName)*"
	$Computers = Get-Content $InputFile | ? {$_ -like $testname}
}
Else
{
	Write-Host "$(Get-Date): Retrieving list of computers from Active Directory"
	If(![String]::IsNullOrEmpty($OrganizationalUnit))
	{
		$Computers = Get-AdComputer -filter {OperatingSystem -like "*server*"} -SearchBase $OrganizationalUnit -SearchScope Subtree -properties DNSHostName, Name -EA 0 | Sort Name
	}
	Else
	{
		$Computers = Get-AdComputer -filter {OperatingSystem -like "*server*"} -properties DNSHostName, Name -EA 0 | Sort Name
	}
}

If($? -and $Null -ne $Computers)
{
	If($Computers -is [array])
	{
		Write-Host "Found $($Computers.Count) servers to process"
	}
	Else
	{
		Write-Host "Found 1 server to process"
	}
	
	$startTime = Get-Date
	If(![String]::IsNullOrEmpty($AccountName))
	{
		$testname = "*$($AccountName)*"
	}
	ElseIf(![String]::IsNullOrEmpty($LiteralAccountName))
	{
		$testname = "$($LiteralAccountName)"
	}

	$Script:AllMatches = @()

	If(![String]::IsNullOrEmpty($InputFile))
	{
		ForEach($Computer in $Computers)
		{
			$TmpComputerName = $Computer
			Write-Host "Testing computer $($TmpComputerName)"
			ProcessComputer $TmpComputerName
		}
	}
	Else
	{
		ForEach($Computer in $Computers)
		{
			$TmpComputerName = $Computer.DNSHostName
			Write-Host "Testing computer $($TmpComputerName)"
			ProcessComputer $TmpComputerName
		}
	}

	$Script:AllMatches | ft SystemName, Name, DisplayName, StartName
	
	$Script:AllMatches | Out-String -width 200 | Out-File -FilePath $Script:FileName

	If(Test-Path "$($Script:FileName)")
	{
		Write-Host "$(Get-Date): $($Script:FileName) is ready for use"
	}
	If(Test-Path "$($Script:FileName2)")
	{
		Write-Host "$(Get-Date): $($Script:FileName2) is ready for use"
	}
	
	Write-Host "$(Get-Date): Script started: $($StartTime)"
	Write-Host "$(Get-Date): Script ended: $(Get-Date)"
	$runtime = $(Get-Date) - $StartTime
	$Str = [string]::format("{0} days, {1} hours, {2} minutes, {3}.{4} seconds", `
		$runtime.Days, `
		$runtime.Hours, `
		$runtime.Minutes, `
		$runtime.Seconds,
		$runtime.Milliseconds)
	Write-Host "$(Get-Date): Elapsed time: $($Str)"
	$runtime = $Null
}
Else
{
	If(![String]::IsNullOrEmpty($ComputerName) -and [String]::IsNullOrEmpty($InputFile))
	{
		#computer name but no input file
		Write-Host "Unable to retrieve a list of computers from Active Directory"
	}
	ElseIf([String]::IsNullOrEmpty($ComputerName) -and ![String]::IsNullOrEmpty($InputFile))
	{
		#input file but no computer name
		Write-Host "Unable to retrieve a list of computers from the Input File $InputFile"
	}
	ElseIf(![String]::IsNullOrEmpty($ComputerName) -and ![String]::IsNullOrEmpty($InputFile))
	{
		#computer name and input file
		Write-Host "Unable to retrieve a list of matching computers from the Input File $InputFile"
	}
	Else
	{
		Write-Host "Unable to retrieve a list of computers from Active Directory"
	}
}