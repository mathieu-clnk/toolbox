$overviewQuery="resources `
| where type == `"microsoft.compute/disks`" `
| where properties.diskState == `"Unattached`" `
| join( resourcecontainers| where type == 'microsoft.resources/subscriptions' `
| project name,subscriptionId,SubscriptionOwner = tags['Email'] ) `
on `$left.subscriptionId == `$right.subscriptionId `
| extend p=parse_json(properties) `
| summarize TotalGB=sum(toint(p['diskSizeGB'])) by location,tostring(sku['tier'])" 
$overview=Search-AzGraph -Query $overviewQuery |ConvertTo-Json

#TODO: correlate with the pricing: https://learn.microsoft.com/en-us/rest/api/billing/enterprise/billing-enterprise-api-pricesheet
Write-Output $overview