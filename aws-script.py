from conjur_iam_client import *

conjur_client = create_conjur_iam_client_from_env()

resources=conjur_client.list()
print(resources)

conjur_client.set("aws-portal/database/username", "Username")
conjur_client.set("aws-portal/database/password", "P@55W0RD123")

db_username=conjur_client.get("aws-portal/database/username")
db_password=conjur_client.get("aws-portal/database/password")

print("Username: {}".format(db_username))
print("Password: {}".format(db_password))