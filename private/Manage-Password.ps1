
function Set-RepositoryPassword {
    param (
        [Parameter(Mandatory)]
        [string]$Key,

        [switch]$Force
    )

    Write-Host "`n🔐 Genrating password for restic repository..." -ForegroundColor Cyan
    if ($Force) {Write-Host "  ├─ Force: $Force"}
    Write-Host "  └─ Key: '$Key'"

    if ((Get-SecretInfo -Name $Key -ErrorAction SilentlyContinue) -and -not $Force) {
        Throw "❌ A password with the key '$Key' already exists. Use -Force to overwrite."
    }

    # Generate a random 256-bit key (32 bytes) and convert it to a printable password
    $bytes = New-Object byte[] 32 # 32 bytes for a 256-bit key
    $rand = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rand.GetBytes($bytes)
    $chars = ([char[]](33..126)) # Printable ASCII characters
    $plainPassword = -join ($bytes | ForEach-Object { $chars[($_ % $chars.Length)] })

    $SecurePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force
    Set-Secret -Name $Key -Secret $SecurePassword

    Write-Host "✅ Created a secure password and stored it." -ForegroundColor Green
}


function Get-RepositoryPassword {
    param (
        [Parameter(Mandatory)]
        [string]$Key 
    )

    if (-not (Get-SecretInfo -Name $Key -ErrorAction SilentlyContinue)) {
        Throw "❌ No password found for the key '$Key'."
    }

    return Get-Secret -Name $Key
}

function Get-DerivedKey {
    param (
        [Parameter(Mandatory)]
        [string]$RepoPath
    )

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($RepoPath))
    return "RepositoryPassword_" + ($encoded -replace "[^a-zA-Z0-9]", "")
}
