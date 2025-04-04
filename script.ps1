﻿param(
    [switch]$ShowConsole,
    [string]$PrimaryColor,
    [string]$SecondaryColor = '#D5DFE5',
    [string]$DarkColor = '#2D3142',
    [string]$AccentBGColor = '#F2F2F2'
)

if (!$PrimaryColor) { $PrimaryColor = ('#0150C6','#3F7854','#DD1155','#1D75AF','#EA1F4B','#864677','#1A7467','#FA0F7D','#C1420B' | Get-Random) }

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'

Import-Module $PSScriptRoot\module.psm1

try { 
    Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase
} catch { 
    Write-Error "Failed to load Windows Presentation Framework assemblies"
}

[xml]$Global:xmlWPF = $ExecutionContext.InvokeCommand.ExpandString((Get-Content -Path "$PSScriptRoot\interface.xaml"))
$Global:xamGUI = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xmlWPF))
$xmlWPF.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $xamGUI.FindName($_.Name) -Scope Global }

$expander.Add_Collapsed({
    $window.Height = $window.MinHeight
})

$expander.Add_Expanded({
    $window.Height = $window.MaxHeight
})

$buttonSearch.Add_Click({
    Search-User -SearchString $textboxSearch.Text
    if ($Global:User) { Update-UI }
})

$textboxSearch.Add_KeyDown({
    if ($_.Key -eq "Return") {
        Search-User -SearchString $textboxSearch.Text
        if ($Global:User) { Update-UI }
    }
})

$comboboxSearch.Add_DropDownClosed({
    $comboboxSearch.IsEnabled = $false
    try { $Global:User = Get-ADUser -Filter {UserPrincipalName -eq $comboboxSearch.Text} -Properties * } catch { $Global:User = $null }
    if ($Global:User) { Update-UI }
})

$buttonReset.Add_Click({
    if ($Global:User) {
        $password = $labelPwdPreview.Content
        try {
            Set-ADAccountPassword $Global:User -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $password -Force)
        } catch { 
            $errorMessage = $_.Exception.Message
            [void][System.Windows.MessageBox]::Show($errorMessage, "Can't change the password", 1, 16)
        }

        if ($checkboxEnable.IsChecked -eq $true -and $checkboxEnable.IsEnabled -eq $true) { Set-ADUser $Global:User -Enabled $true }
        if ($checkboxUnlock.IsChecked -eq $true -and $checkboxUnlock.IsEnabled -eq $true) { Unlock-ADAccount $Global:User }
        if ($checkboxChangePwd.IsChecked -eq $true) { Set-ADUser $Global:User -ChangePasswordAtLogon $true }

        if ($null -eq $errorMessage) {
            [void][System.Windows.MessageBox]::Show("The new password has been copied to your clipboard: $password", "Password reset", 1, 64)
            $password | Set-Clipboard
        }

        $Global:User = Get-ADUser $Global:User -Properties *
        Update-UI
    }
})

$slider.Add_ValueChanged({
    $labelPwdPreview.Content = New-Password -Length $slider.Value
    $labelPwdPreview.ToolTip = $labelPwdPreview.Content
})

$buttonRegen.Add_Click({
    $labelPwdPreview.Content = New-Password -Length $slider.Value
    $labelPwdPreview.ToolTip = $labelPwdPreview.Content
})

$buttonClipboard.Add_Click({
    $labelPwdPreview.Content | Set-Clipboard
})

$buttonClear.Add_Click({
    Clear-UI
})

$buttonCancel.Add_Click({
    $xamGUI.Close()
    break
})

if (!$ShowConsole.IsPresent) { $null = Hide-Console }
$null = $xamGUI.ShowDialog()
