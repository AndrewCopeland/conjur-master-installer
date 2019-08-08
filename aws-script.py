from conjur_iam_client import *

conjur_client = create_conjur_iam_client_from_env()

resources=conjur_client.list()
print(resources)

conjur_client.set("aws-portal/database/username", "Username")
conjur_client.set("aws-portal/database/password", "P@55W0RD123")

print(conjur_client.get("aws-portal/database/username"))
print(conjur_client.get("aws-portal/database/password"))