Import-Module .\dell.apex.psm1 -Force

# SPECIFY THE ORG
$org = 'MyOrg'

# CONNECT TO THE APEX API
connect-restapi -Uri "apis-us0.druva.com" -Endpoint "phoenix"

# GET THE ORG
$query = get-org -Org $org


# FILTER FOR FAILURES BY DATE
$Filters = @(
    "minGeneratedOn=2023-05-08T00:00:01Z",
    "maxGeneratedOn=2023-05-30T23:59:59Z"
)
$failures = get-alerts -Org $query.id -Filters $Filters

$failures | sort-object generatedOn | format-list

# $failures | Export-Csv .\alerts.csv -NoTypeInformation