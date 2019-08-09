yum install python3

# install python3 client
pip3 install conjur-client

# install iam key module
git clone https://github.com/AndrewCopeland/conjur-iam-api-key.git
cd conjur-iam-api-key
pip3 install .
cd ..
rm -r conjur-iam-api-key

# yum erase python3