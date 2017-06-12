@ECHO OFF
REM  QBFC Project Options Begin
REM  HasVersionInfo: Yes
REM  Companyname: TechVD
REM  Productname: Automated Bulk User Creation
REM  Filedescription: 
REM  Copyrights: Copyright Jackson Van Dyke 2013
REM  Trademarks: 
REM  Originalname: 
REM  Comments: 
REM  Productversion:  0. 9. 0. 0
REM  Fileversion:  0. 0. 0. 0
REM  Internalname: 
REM  Appicon: 
REM  AdministratorManifest: No
REM  QBFC Project Options End
ECHO ON

@echo off

:: Bulk User Creator - Jackson Van Dyke 2013-2015 (1.15 - cf)

title Bulk User Creator
echo Bulk User Creator

:: COMMENTS
:: First part - Adds users from an Excel document - C:\UserList.csv and adds them to selected groups
:: Second part - Writes that it successfully created the selected user to a file: UserLog.txt
:: Third part - Grants students change permissions for their Home Directories and staff full permissions for their Home Directories
:: Fourth part - Creates a text file in their Home Directory to test the permissions, if it was inserted it was successful
:: Fifth part - Creates a PS file that creates a mailbox for the users
:: Sixth part - Exits the script after iterating through all users

:: INITIALISE CUSTOM VARIABLES

SetLocal EnableDelayedExpansion
set L=1

for /F "tokens=* delims=," %%a in (Settings.ini) do (
  if !L!==4 set UserListPath=%%a
  if !L!==6 set ICTGroup=%%a
  if !L!==8 set TeachersGroup=%%a
  if !L!==10 set StudentsGroup=%%a
  if !L!==12 set DomainPath=%%a
  if !L!==14 set TDomainPath=%%a
  if !L!==16 set ExchangeServer=%%a
  if !L!==18 set StaffEmails=%%a
  if !L!==20 set StudentEmails=%%a
  if !L!==22 set MailboxDatabase=%%a
  if !L!==24 set DSuffix=%%a
  if !L!==26 set StExtraGroups=%%a
  if !L!==28 set TeExtraGroups=%%a
  if !L!==30 set ITExtraGroups=%%a
  if !L!==32 set YearLevelG=%%a
  if !L!==34 set DomainController=%%a
  if !L!==36 set StudentOU=%%a
  if !L!==38 set StaffOU=%%a
  if !L!==40 set Password1=%%a
  if !L!==42 set Password2=%%a
  if !L!==44 set StaffDatabase=%%a
  set  /a  L=!L!+1
)

:: COMMA DELIMITED VARIABLES

set Original=YEARLVL
set StaffOUFinal= ou=%StaffOU:.-,ou=%
set StudentOUFinal= ou=%StudentOU:.-,ou=%
set DomainName= dc=%dsuffix:.=,dc=%

:: USER CREATION

for /f "skip=1 Tokens=1,2,3,4 Delims=," %%a in (%UserListPath%) do (

set User=%%a
set YearLevel=%%d

echo $session = New-PSSession -computerName %DomainController% >> AddUsers.ps1
echo Import-PSSession $Session >> AddUsers.ps1
if "%%b"=="Students" (
  echo Invoke-command { dsadd user "cn=%%a,%StudentOUFinal%,%DomainName%" -display "%%c" -pwd "%Password1%" -canchpwd yes -pwdneverexpires yes -mustchpwd yes} -session $Session >> AddUsers.ps1
 ) else (
  echo Invoke-command { dsadd user "cn=%%a,%StaffOUFinal%,%DomainName%" -display "%%c" -pwd "%Password2%" -canchpwd yes -pwdneverexpires yes -mustchpwd yes} -session $Session >> AddUsers.ps1
)

powershell -executionpolicy Unrestricted -file .\AddUsers.ps1 >nul
del .\AddUsers.ps1 >nul

if not errorlevel 0 (
  echo Failed to add users, check UserList syntax && timeout /t 5 >nul && exit /b 0
 )
if "%%b"=="ICT Support" (net group "%ICTGroup%" /domain %%a /add >nul)
if "%%b"=="Teachers" (net group "%TeachersGroup%" /domain %%a /add >nul)
if "%%b"=="Students" (net group "%StudentsGroup%" /domain %%a /add >nul)

echo.
echo Added %%a to %%b on domain %userdomain% >> UserLog.txt
echo %%a added to %%b successfully

if NOT "%%b"=="Students" (echo %%a added with default password: %Password2%)
if "%%b"=="Students" (echo %%a added with default password: %Password1%)
echo.

if "%%b"=="Students" (

  md "%DomainPath%\%%d\%%a" >nul && cacls "%DomainPath%\%%d\%%a" /e /p %%a:C >nul && echo Granted change permissions for %%a in directory: %DomainPath%\%%d\%%a 
  net user %%a /homedir:"%DomainPath%\%%d\%%a" /domain >nul
  net user %%a /logonpasswordchg:yes /domain >nul
  set "GroupsAdd=net group /domain %StExtraGroups:,= /add !User! >nul && net group /domain %"
  call :GroupsAdd
  call :YearLevelAdd

 ) else (

  md "%TDomainPath%\%%a" >nul
  cacls "%TDomainPath%\%%a" /e /p %%a:C >nul
  echo Granted change permissions for %%a in directory: %TDomainPath%\%%a
  net user %%a /homedir:"%TDomainPath%\%%a" /domain >nul
  net user %%a /logonpasswordchg:yes /domain >nul

if "%%b"=="Teachers" (set "GroupsAdd=net group /domain %TeExtraGroups:,= /add !User! >nul && net group /domain %" && call :GroupsAdd)
if "%%b"=="ICT Support" (set "GroupsAdd=net group /domain %ITExtraGroups:,= /add !User! >nul && net group /domain %" && call :GroupsAdd)

echo If this shows up in a txt document the commands successfully completed. >> "%TDomainPath%\%%a\%%a - Success.txt"
 if not ErrorLevel 0 (
  echo Failed to implant text document, check your permissions
 ) else (
  del "%TDomainPath%\%%a\%%a - Success.txt" 
 )
)

echo $s = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://%ExchangeServer%/powershell >> Mailbox.ps1
echo Import-PSSession $s >> Mailbox.ps1

if NOT "%%b"=="Students" (echo Get-MailboxDatabase -identity "%MailboxDatabase%" ^| Add-ADPermission -user %%a -AccessRights GenericAll >> Mailbox.ps1 && echo Add-DistributionGroupMember -Identity %StaffEmails% -Member %%a >> Mailbox.ps1 && echo Enable-Mailbox %%a -Database "%StaffDatabase%">> Mailbox.ps1)

if "%%b"=="Students" (echo Add-DistributionGroupMember -Identity %StudentEmails% -Member %%a >> Mailbox.ps1
echo Add-DistributionGroupMember -Identity %%d -Member %%a >> Mailbox.ps1 && echo Enable-Mailbox %%a -Database "%MailboxDatabase%">> Mailbox.ps1)

powershell -executionpolicy unrestricted -file .\Mailbox.ps1 >nul
if not ErrorLevel 0 (
  echo Error creating mailbox for user.
 ) else (
  echo Mailbox successfully created for %%a
 )
del Mailbox.ps1 >nul


)

:: Runs on completion of script

:Exit

echo.
echo Successfully added users
echo Exiting..
echo.
timeout /t 2 >nul
exit /b 0

:: Makes it easier to add users to groups

:GroupsAdd

%GroupsAdd% /add %User% >nul
goto :EOF

:: Add students to Year Groups - can likely be cleaned up

:YearLevelAdd

set replacement=%YearLevel%
set YearLevelF=%YearLevelG%
set YearLevelF=%YearLevelF:!Original!=!replacement!%
call set YearLevelF=%%YearLevelF:%Original%=%replacement%%%
set "YearLevelA=net group /domain %YearLevelF:,= /add !User! >nul && net group /domain %"
%YearLevelA% /add %User% >nul

goto :EOF