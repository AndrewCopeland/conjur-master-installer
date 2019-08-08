from conjur_iam_client import *
conjur_client = create_conjur_iam_client_from_env()
print(conjur_client.list())
