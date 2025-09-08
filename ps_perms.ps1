# Compare-DatabasePermissions.ps1
# This script compares permissions between two SQL Server databases using dbatools

# Parameters for SQL Server connection and database names
param (
    [Parameter(Mandatory=$true)]
    [string]$ServerInstance,
    [Parameter(Mandatory=$true)]
    [string]$Database1,
    [Parameter(Mandatory=$true)]
    [string]$Database2,
    [string]$Username,
    [string]$Password
)

# Import dbatools module
Import-Module dbatools -ErrorAction Stop

try {
    # Set up connection parameters
    $connectionParams = @{
        SqlInstance = $ServerInstance
    }
    if ($Username -and $Password) {
        $connectionParams.Add('SqlCredential', (New-Object System.Management.Automation.PSCredential($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))))
    }

    # Connect to SQL Server instance
    $server = Connect-DbaInstance @connectionParams -ErrorAction Stop

    # Function to get database permissions
    function Get-DatabasePermissions {
        param (
            [Microsoft.SqlServer.Management.Smo.Server]$Server,
            [string]$Database
        )

        $permissions = @()
        $db = $Server.Databases[$Database]
        if (-not $db) {
            throw "Database $Database not found on $ServerInstance"
        }

        $query = @"
        SELECT 
            p.class_desc,
            p.permission_name,
            p.state_desc,
            pr.name AS principal_name,
            o.name AS object_name,
            SCHEMA_NAME(o.schema_id) AS schema_name
        FROM sys.database_permissions p
        JOIN sys.database_principals pr ON p.grantee_principal_id = pr.principal_id
        LEFT JOIN sys.objects o ON p.major_id = o.object_id
        WHERE p.major_id >= 0
        ORDER BY pr.name, p.permission_name, o.name
"@

        $result = $db.Query($query)
        
        foreach ($row in $result) {
            $permissions += [PSCustomObject]@{
                Database = $Database
                Principal = $row.principal_name
                Permission = $row.permission_name
                State = $row.state_desc
                Object = $row.object_name
                Schema = $row.schema_name
                Class = $row.class_desc
            }
        }
        
        return $permissions
    }

    # Get permissions for both databases
    Write-Host "Retrieving permissions for $Database1..."
    $perms1 = Get-DatabasePermissions -Server $server -Database $Database1
    Write-Host "Retrieving permissions for $Database2..."
    $perms2 = Get-DatabasePermissions -Server $server -Database $Database2

    # Compare permissions
    Write-Host "`nComparing permissions..."

    # Convert permissions to comparable strings
    $perms1Set = $perms1 | ForEach-Object {
        "$($_.Principal)|$($_.Permission)|$($_.State)|$($_.Object)|$($_.Schema)|$($_.Class)"
    } | Sort-Object

    $perms2Set = $perms2 | ForEach-Object {
        "$($_.Principal)|$($_.Permission)|$($_.State)|$($_.Object)|$($_.Schema)|$($_.Class)"
    } | Sort-Object

    # Find differences
    $diff1 = Compare-Object -ReferenceObject $perms1Set -DifferenceObject $perms2Set | 
        Where-Object { $_.SideIndicator -eq '<=' } | 
        ForEach-Object { 
            $parts = $_.InputObject.Split('|')
            [PSCustomObject]@{
                Database = $Database1
                Principal = $parts[0]
                Permission = $parts[1]
                State = $parts[2]
                Object = $parts[3]
                Schema = $parts[4]
                Class = $parts[5]
            }
        }

    $diff2 = Compare-Object -ReferenceObject $perms1Set -DifferenceObject $perms2Set | 
        Where-Object { $_.SideIndicator -eq '=>' } | 
        ForEach-Object { 
            $parts = $_.InputObject.Split('|')
            [PSCustomObject]@{
                Database = $Database2
                Principal = $parts[0]
                Permission = $parts[1]
                State = $parts[2]
                Object = $parts[3]
                Schema = $parts[4]
                Class = $parts[5]
            }
        }

    # Output results
    if ($diff1.Count -eq 0 -and $diff2.Count -eq 0) {
        Write-Host "No permission differences found between $Database1 and $Database2." -ForegroundColor Green
    } else {
        Write-Host "`nPermissions unique to $Database1:" -ForegroundColor Yellow
        $diff1 | Format-Table -AutoSize

        Write-Host "Permissions unique to $Database2:" -ForegroundColor Yellow
        $diff2 | Format-Table -AutoSize
    }

} catch {
    Write-Error "An error occurred: $_"
} finally {
    # Clean up connection
    if ($server) {
        $server.ConnectionContext.Disconnect()
    }
}
