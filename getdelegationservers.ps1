$servers = @("s1", "s2", "s3")

$delegationTargets = Get-ADServiceAccount -Identity "serviceaccount" -Properties msDS-AllowedToDelegateTo |
    Select-Object -ExpandProperty msDS-AllowedToDelegateTo

$filteredTargets = $delegationTargets | Where-Object {
    $hostname   = ($_ -split "/")[-1]        # Strip "MSSQLSvc/" prefix
    $servername = ($hostname -split "[.:]")[0] # Strip domain and port
    $servers -contains $servername
}

$filteredTargets
