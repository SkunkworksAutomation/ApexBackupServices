Import-Module .\dell.apex.psm1 -Force

# SPECIFY THE ORG
$org = 'MyOrg'

# CONNECT TO THE APEX API
connect-restapi -Uri "https://apis-us0.druva.com" -Endpoint "phoenix"

# GET THE ORG
$query = get-org -Org $org


# BACKUP JOBS FILTERED BY VM AND DATE
# Backup, Restore, Log Request, Defreeze

$Filters = @(
    "vmName=vc1-win-01.vcorp.local",
    "status=Successful",
    "fromTime=2023-02-24T00:00:01Z",
    "toTime=2023-05-01T23:59:59Z"
)
$images = get-backupjobs -Org $query.id -Filters $Filters

$images | format-list

# $images | Export-Csv .\jobs.csv -NoTypeInformation