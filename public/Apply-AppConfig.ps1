function Apply-AppConfig {
    <#
    .SYNOPSIS
        Applies application configurations defined in an external YAML file.

    .DESCRIPTION
        Reads a YAML configuration file that defines one or more applications, ensures each app is installed
        via Test-Dependency, and applies the configuration keys/values idempotently.
        Supports placeholder replacement from $Parameters for dynamic values like usernames/emails.

    .PARAMETER ConfigPath
        Path to the YAML configuration file describing applications and their settings.

    .EXAMPLE
        Apply-AppConfig -ConfigPath "./config/appconfig.yaml" -Parameters @{ "git.user.name"="Alice"; "git.user.email"="alice@example.com" }

    .NOTES
        Author: Jan Hoegen
        Part of: My-System-Setup
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "$PSScriptRoot/../config/appconfig.yaml"

    )
    Test-Dependency -Command "ConvertFrom-Yaml" -Module -Source "powershell-yaml"

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found at '$ConfigPath'."
    }
    try {
        $config = (Get-Content -Path $ConfigPath -Raw) | ConvertFrom-Yaml
    } catch {
        throw "Failed to parse configuration: $_"
    }

    foreach ($appName in $config.apps.Keys) {
        $app = $config.apps.$appName

        Write-Verbose "Processing application '$appName'..."

        # Ensure dependency is installed
        if ($PSCmdlet.ShouldProcess("App $appName", "Check dependency")) {
            Test-Dependency -Command $app.command -App -Source $app.source
        }

        # Apply each config key
        foreach ($key in $app.config.Keys) {
            $value = $app.config.$key

            # TODO: parameterize the values. use a environment variable
            
            if ($PSCmdlet.ShouldProcess("App $appName", "Set $key = $value")) {
                try {
                    # For Git, we can assume command-line config keys
                    # This could be extended for other apps
                    switch ($appName.ToLower()) {
                        'git' {
                            $current = git config --global $key 2>$null
                            if ($current -ne $value) {
                                git config --global $key $value
                                Write-Verbose "Set Git $key = $value"
                            } else {
                                Write-Verbose "Git $key already set to $value, skipping."
                            }
                        }
                        'office' {
                            # Only run once per app, not per config key
                            if ($PSCmdlet.ShouldProcess("Office", "Install MS Office")) {
                                $xmlPath = $app.config.configXmlPath
                                if (-not (Test-Path $xmlPath)) {
                                    Write-Error "Office configuration XML not found at '$xmlPath'."
                                    break
                                }

                                # Set location to Office Deployment Tool folder
                                $odtFolder = Split-Path $xmlPath
                                Set-Location $odtFolder

                                try {
                                    Write-Verbose "Running Office setup using '$xmlPath'..."
                                    & .\setup.exe /configure $xmlPath
                                    Write-Verbose "Office installation finished."
                                } catch {
                                    Write-Error "Office installation failed: $_"
                                }
                            }
                        }

                        'oh-my-posh' {
                        if ($PSCmdlet.ShouldProcess("Oh-My-Posh", "Setup Oh-My-Posh environment")) {

                            # 1. Ensure oh-my-posh is installed
                            Test-Dependency -Command "oh-my-posh" -App -Source "jandedobbeleer.oh-my-posh"

                            $font = $app.config.fontName
                            $profilePath = $app.config.profilePath
                            $wtSettings = $app.config.windowsTerminalSettings
                            $vscodeSettings = $app.config.vscodeSettings
                            $initLine = 'oh-my-posh init pwsh | Invoke-Expression'

                            # 2. Install Meslo font if not present
                            $fontInstalled = (Get-CimInstance Win32_FontInfoAction | Where-Object { $_.Caption -like "*$font*" }).Count -gt 0
                            if (-not $fontInstalled) {
                                Write-Verbose "Installing Oh-My-Posh font '$font'..."
                                oh-my-posh font install $font
                            } else {
                                Write-Verbose "Font '$font' already installed, skipping."
                            }

                            # 3. Update PowerShell profile
                            if (-not (Test-Path $profilePath)) { New-Item -Path $profilePath -ItemType File -Force | Out-Null }
                            if (-not (Get-Content $profilePath | Select-String -Pattern [regex]::Escape($initLine))) {
                                Add-Content -Path $profilePath -Value "`n$initLine"
                                Write-Verbose "Added Oh-My-Posh init line to PowerShell profile."
                            } else {
                                Write-Verbose "PowerShell profile already contains Oh-My-Posh init line."
                            }

                            # 4. Configure Windows Terminal font
                            if (Test-Path $wtSettings) {
                                $wtJson = Get-Content $wtSettings -Raw | ConvertFrom-Json
                                if (-not $wtJson.profiles) { $wtJson | Add-Member -MemberType NoteProperty -Name profiles -Value @{} }
                                if (-not $wtJson.profiles.defaults) { $wtJson.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value @{} }
                                $wtJson.profiles.defaults.font.face = $font
                                $wtJson | ConvertTo-Json -Depth 10 | Set-Content $wtSettings -Encoding UTF8
                                Write-Verbose "Windows Terminal default font set to '$font'."
                            } else {
                                Write-Warning "Windows Terminal settings.json not found, skipping font update."
                            }
                        }
                    }

                        default {
                            Write-Error "No handler implemented for '$appName'."
                        }
                    }
                } catch {
                    Write-Error "Failed to set '$key' for '$appName': $_"
                }
            }
        }
    }
    Write-Host "All app configurations applied successfully." -ForegroundColor Green
}
 