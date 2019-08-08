from conjur_iam_client import *

def get_all_variables(resources):
    for resource in resources:
        if ":variable:" in resource:
            secret_id=resource.split(":", 3)[2]
            return secret_id


conjur_client = create_conjur_iam_client_from_env()

resources=conjur_client.list()
print(resources)

all_secrets = get_all_variables(resources)

# Setting conjur secrets
for secret in all_secrets:
    if "username" in secret:
        conjur_client.set(secret, "Username")
    if "password" in secret:
        conjur_client.set(secret, "P@55W0RD123")

# fetching the conjur secrets
for secret in all_secrets:
    print("{}: {}".format(secret, conjur_client.get(secret)))