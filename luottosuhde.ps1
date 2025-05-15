#--------------Luottosuhteen muodostaminen kahden toimialueen välille---------------
#-----------------------Skripti suoritetaan palvelin 1:stä--------------------------

# Palvelin 1 (palvelinkomento) : IP-asetukset

# Ennalta määritetty IP-osoite: 10.20.30.100

$haluttuIP = "10.20.30.100"
$toissijainenIP = "10.20.30.200"
$interfaceAlias = "Ethernet"
$aliverkonMaski = 24
$tarkistaIP = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $interfaceAlias -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -eq $haluttuIP}

# Write-Host "tarkistaIP arvo on: $tarkistaIP"

Write-Host "IP-osoitteen tarkistus: Muutetaan tarvittaessa..."

# Jos IP:tä ei löydy / ole oikea, luodaan / muutetaan se oikeaksi
if($tarkistaIP -eq $null) {
	Write-Host "IP-osoite ei ollut $haluttuIP"
	New-NetIPAddress -IPAddress $haluttuIP -InterfaceAlias $interfaceAlias -PrefixLength $aliverkonMaski
	Write-Host "IP-osoite muutettu: $haluttuIP"
} else {
	Write-Host "IP-osoite on jo $haluttuIP"
}

Write-Host "DNS-osoitteiden tarkistus: Muutetaan tarvittaessa..."

# Jos DNS-osoitteet eivät täsmää haluttuja, muutetaan ne oikeiksi
$tarkistaDNS = Get-DnsClientServerAddress -InterfaceAlias $interfaceAlias -AddressFamily IPv4

if (($tarkistaDNS.ServerAddresses -contains $haluttuIP) -and ($tarkistaDNS.ServerAddresses -contains $toissijainenIP)) {
    Write-Host "DNS-osoitteet ovat jo oikein: $haluttuIP ja $toissijainenIP"
} else {
    Write-Host "DNS-osoitteet eivät ole oikein, muutetaan ne..."
    Set-DnsClientServerAddress -InterfaceAlias $interfaceAlias -ServerAddresses ($haluttuIP, $toissijainenIP)
    Write-Host "DNS-osoitteet muutettu. 'Preferred': $haluttuIP, 'Alternate': $toissijainenIP"
}

# Kaksisuuntaisen luottosuhteen muodostaminen toimialueiden välille

$ekapalvelin = "testimetsa24.edu"
$tokapalvelin_toimialue = "toinentestimetsa24.edu"
$tokapalvelin_admin = "toinentestimetsa24.edu\Administrator"

# Noudetaan tokapalvelin admin salasana tiedostosta

$tokapalvelinAdminSS = Get-Content -Path "C:\Domain_admin_pw\password_other_domain_admin.txt"
$tokapalvelinAdminSS = $tokapalvelinAdminSS.Trim()

# Tarkistetaan, onko luottosuhde jo olemassa

Write-Host "Tarkistetaan luottosuhde toimialueiden välillä..."
$haeLuottosuhde = Get-ADTrust -Filter "Target -eq '$tokapalvelin_toimialue'" -ErrorAction SilentlyContinue
Write-Host "Luottosuhde Get-ADTrust komennon avulla on seuraava: $haeLuottosuhde"

if($haeLuottosuhde -eq $null) {
	Write-Host "Luottosuhdetta ei ole vielä luotu toimialueelle $tokapalvelin_toimialue"
	Write-Host "Luodaan uusi luottosuhde..."
	try {
		$yhteysSisalto = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext `
        ("Forest", $tokapalvelin_toimialue, $tokapalvelin_admin, $tokapalvelinAdminSS)
        # Write-Host "Yhteyssisältö on: $yhteysSisalto"
		$paikallinenMetsa=[System.DirectoryServices.ActiveDirectory.Forest]::getCurrentForest()
        Write-Host "paikallinenMetsa on: $paikallinenMetsa"
		$etaMetsa = [System.DirectoryServices.ActiveDirectory.Forest]::getForest($yhteysSisalto)
        Write-Host "etaMetsa on: $etaMetsa"
		$paikallinenMetsa.CreateTrustRelationship($etaMetsa,"Bidirectional")
        Write-Host "Luottosuhteen muodostaminen onnistui toimialueen $($etaMetsa.Name) ja $($paikallinenMetsa.Name) välille!"

        # Luodaan viive, jotta luottosuhde astuu voimaan ja tämän skriptin muiden asetusten säätäminen onnistuu paremmin
        Write-Host "Odotetaan 30 sekuntia, jotta luottosuhde rekisteröityy täysin..."
        Start-Sleep -Seconds 30
    	} catch {
        Write-Warning "Luottosuhteen muodostaminen epäonnistui: $($_.Exception.Message)"
    	}	
} else {
    Write-Host "Luottosuhde on jo muodostettu toimialueiden välille."
}

# Luodaan kansio molemmille toimialueen käyttäjille

Write-Host "Tarkistetaan, onko luottosuhdekansio Trusted-partners-kansio jo luotu..."
$kansioPolku = "C:\Trusted-partners-kansio"
$kansioNimi = "Trusted-partners-kansio"
$tarkistaKansio = Test-Path -Path $kansioPolku

if($tarkistaKansio -eq $false) {
    Write-Host "$kansioNimi kansio ei ole vielä luotu. Luodaan uusi..."
    New-Item -Path $kansioPolku -ItemType Directory
    Write-Host "Uusi kansio Trusted-partners-kansio on luotu!"
} else {
    Write-Host "Kansio on jo olemassa."
}

# Tarkistetaan kansion jako toimialueiden käyttäjille. Jos ei ole jaettu, samalla määritetään käyttöoikeudet

Write-Host "Tarkistetaan, onko kansio $kansioNimi jo jaettu..."
$tarkistaJako = Get-SmbShare -Name $kansioNimi -ErrorAction SilentlyContinue
if($tarkistaJako -eq $null -or $tarkistaJako -eq $false) {
    Write-Host "Kansio $kansioNimi ei ole vielä jaettu. Luodaan jako..."
    New-SmbShare -Name $kansioNimi -Path $kansioPolku -FullAccess "testimetsa24.edu\Domain Users"
    Grant-SmbShareAccess -Name $kansioNimi -AccountName "toinentestimetsa24.edu\Domain Users" -AccessRight Full -Force
    Write-Host "Jako luotu toimialueille $ekapalvelin ja $tokapalvelin_toimialue !"

    # Määritetään kansion käyttöoikeudet

    Write-Host "Määritetään käyttöoikeudet..."
    $kayttoOikeus = Get-Acl $kansioPolku
    $testimetsa24Oikeus = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ("testimetsa24.edu\Domain Users", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
    $toinentestimetsa24Oikeus = New-Object System.Security.AccessControl.FileSystemAccessRule `
    ("toinentestimetsa24.edu\Domain Users", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
    $kayttoOikeus.SetAccessRule($testimetsa24Oikeus)
    $kayttoOikeus.SetAccessRule($toinentestimetsa24Oikeus)
    Set-Acl -Path $kansioPolku -AclObject $kayttoOikeus
    Write-Host "Käyttöoikeudet määritetty."
} else {
    Write-Host "Kansio on jo jaettu."
}

# Luodaan yhteinen tekstitiedosto, jota molempien toimialueiden käyttäjät voivat muokata

Write-Host "Tarkistetaan, onko yhteinen tekstitiedosto jo luotu..."
$tekstitiedostoPolku = "C:\Trusted-partners-kansio\Secret_file.txt"
$tarkistaTekstitiedosto = Get-Item -Path $tekstitiedostoPolku -ErrorAction SilentlyContinue
if($tarkistaTekstitiedosto -eq $null) {
    Write-Host "Tekstitiedosto ei ole vielä luotu. Luodaan uusi..."
    New-Item -Path $tekstitiedostoPolku -ItemType File
    Write-Host "Tekstitiedosto luotu."
} else {
    Write-Host "Tekstitiedosto on jo olemassa."
}

Write-Host "Skripti suoritettu loppuun."