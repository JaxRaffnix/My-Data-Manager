# My-Backup-Apply

- add terminal json to apply config
- powertoys peek keybind?

the apps yaml does not work. structure code execution and config data differently.

TODO: 
```
New-ItemProperty -Path "HKLM:\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" `
  -Name "ExecutionPolicy" -Value "Bypass" -PropertyType String -Force

Set-ItemProperty -Path "HKLM:\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" `
  -Name "NoLogo" -Value 1 -Type DWord
```


`git config --global core.editor "code --wait"`


zu path hinzufügen: `"C:\Program Files\Inkscape\bin"`