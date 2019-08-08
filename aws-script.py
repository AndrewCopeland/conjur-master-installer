from conjur_iam_client import *
conjur_client = create_conjur_iam_client_from_env()

resources=conjur_client.list()
print(resources)

for resource in resources:
    if ":variable:" in resource:
        secret_id=resource.split(":", 3)[2]
        print("{}: {}".format(secret_id, conjur_client.get(secret_id)))