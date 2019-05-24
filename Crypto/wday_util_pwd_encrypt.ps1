$userToEncrypt = 'user_cred'
$pwdToEncrypt = 'Xwy2qsf#123d3&a'
$filePath = 'C:\Temp\Data\user_credential.json'

$secure = ConvertTo-SecureString -String $pwdToEncrypt -AsPlainText -Force
$cred = New-Object -typename PSCredential -ArgumentList @($userToEncrypt,$secure)
$cred | Select Username,@{Name="Password";Expression = { $_.password | ConvertFrom-SecureString }} |  Convertto-Json | Out-File $filePath