```bash
#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# AI ENGINEER LAB - DEVELOPMENT ENVIRONMENT BOOTSTRAP
# ============================================================
#
# Installs / verifies:
#   - Python 3.14
#   - pip
#   - AWS CLI
#   - Terraform
#   - Python virtual environment
#   - Python packages from requirements.txt
#
# AWS:
#   - Uses profile: ai-profile
#   - Stores credentials in ~/.aws/credentials
#   - Stores configuration in ~/.aws/config
#
# Safe to run multiple times.
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AWS_PROFILE="ai-profile"
AWS_REGION="${AWS_REGION:-ap-south-1}"

VENV_DIR="${PROJECT_ROOT}/.venv"
REQUIREMENTS_FILE="${PROJECT_ROOT}/requirements.txt"

echo
echo "============================================================"
echo "           AI ENGINEER LAB - BOOTSTRAP"
echo "============================================================"
echo
echo "Project root : ${PROJECT_ROOT}"
echo "AWS profile  : ${AWS_PROFILE}"
echo "AWS region   : ${AWS_REGION}"
echo


# ============================================================
# Helper functions
# ============================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}


install_apt_package() {
    local package="$1"

    if dpkg -s "$package" >/dev/null 2>&1; then
        echo "✓ ${package} already installed"
    else
        echo "Installing ${package}..."
        sudo apt-get update -y
        sudo apt-get install -y "$package"
    fi
}


# ============================================================
# 1. System update
# ============================================================

echo "------------------------------------------------------------"
echo "1. Checking system"
echo "------------------------------------------------------------"

if command_exists apt-get; then
    echo "✓ Debian/Ubuntu based environment detected"
else
    echo "ERROR: This bootstrap script currently expects a"
    echo "Debian/Ubuntu based GitHub Codespace."
    exit 1
fi


# ============================================================
# 2. Install basic dependencies
# ============================================================

echo
echo "------------------------------------------------------------"
echo "2. Installing base dependencies"
echo "------------------------------------------------------------"

sudo apt-get update -y

sudo apt-get install -y \
    curl \
    unzip \
    wget \
    git \
    ca-certificates \
    software-properties-common \
    python3.14 \
    python3.14-venv \
    python3.14-dev


# ============================================================
# 3. Verify Python 3.14
# ============================================================

echo
echo "------------------------------------------------------------"
echo "3. Checking Python"
echo "------------------------------------------------------------"

if ! command_exists python3.14; then
    echo "ERROR: Python 3.14 installation failed."
    exit 1
fi

PYTHON_VERSION=$(python3.14 --version)

echo "Python: ${PYTHON_VERSION}"

if [[ "${PYTHON_VERSION}" != Python\ 3.14* ]]; then
    echo "ERROR: Python 3.14 is required."
    exit 1
fi

echo "✓ Python 3.14 verified"


# ============================================================
# 4. Create virtual environment
# ============================================================

echo
echo "------------------------------------------------------------"
echo "4. Creating Python virtual environment"
echo "------------------------------------------------------------"

if [[ -d "${VENV_DIR}" ]]; then
    echo "✓ Virtual environment already exists"
else
    python3.14 -m venv "${VENV_DIR}"
    echo "✓ Created ${VENV_DIR}"
fi

source "${VENV_DIR}/bin/activate"

echo
echo "Python executable:"
which python

echo
python --version


# ============================================================
# 5. Upgrade pip
# ============================================================

echo
echo "------------------------------------------------------------"
echo "5. Updating pip"
echo "------------------------------------------------------------"

python -m pip install --upgrade pip setuptools wheel


# ============================================================
# 6. Install Python packages
# ============================================================

echo
echo "------------------------------------------------------------"
echo "6. Installing Python packages"
echo "------------------------------------------------------------"

if [[ ! -f "${REQUIREMENTS_FILE}" ]]; then
    echo "ERROR: requirements.txt not found:"
    echo "  ${REQUIREMENTS_FILE}"
    exit 1
fi

python -m pip install -r "${REQUIREMENTS_FILE}"

echo "✓ Python packages installed"


# ============================================================
# 7. Install AWS CLI
# ============================================================

echo
echo "------------------------------------------------------------"
echo "7. Checking AWS CLI"
echo "------------------------------------------------------------"

if command_exists aws; then

    echo "✓ AWS CLI already installed"
    aws --version

else

    echo "Installing AWS CLI..."

    AWS_CLI_ZIP="/tmp/awscliv2.zip"
    AWS_CLI_DIR="/tmp/aws"

    rm -rf "${AWS_CLI_DIR}"
    rm -f "${AWS_CLI_ZIP}"

    curl -fsSL \
        "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o "${AWS_CLI_ZIP}"

    unzip -q "${AWS_CLI_ZIP}" -d /tmp

    sudo /tmp/aws/install

    rm -rf "${AWS_CLI_DIR}"
    rm -f "${AWS_CLI_ZIP}"

    echo "✓ AWS CLI installed"

fi

aws --version


# ============================================================
# 8. Install Terraform
# ============================================================

echo
echo "------------------------------------------------------------"
echo "8. Checking Terraform"
echo "------------------------------------------------------------"

if command_exists terraform; then

    echo "✓ Terraform already installed"
    terraform version

else

    echo "Installing Terraform..."

    TERRAFORM_VERSION="1.13.3"

    TERRAFORM_ZIP="/tmp/terraform.zip"

    curl -fsSL \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
        -o "${TERRAFORM_ZIP}"

    unzip -o "${TERRAFORM_ZIP}" -d /tmp

    sudo mv /tmp/terraform /usr/local/bin/terraform

    rm -f "${TERRAFORM_ZIP}"

    echo "✓ Terraform installed"

fi

terraform version


# ============================================================
# 9. AWS configuration directory
# ============================================================

echo
echo "------------------------------------------------------------"
echo "9. Preparing AWS configuration"
echo "------------------------------------------------------------"

AWS_DIR="${HOME}/.aws"
AWS_CREDENTIALS_FILE="${AWS_DIR}/credentials"
AWS_CONFIG_FILE="${AWS_DIR}/config"

mkdir -p "${AWS_DIR}"

chmod 700 "${AWS_DIR}"

touch "${AWS_CREDENTIALS_FILE}"
touch "${AWS_CONFIG_FILE}"

chmod 600 "${AWS_CREDENTIALS_FILE}"
chmod 600 "${AWS_CONFIG_FILE}"

echo "AWS directory:"
echo "  ${AWS_DIR}"

echo "Credentials file:"
echo "  ${AWS_CREDENTIALS_FILE}"

echo "Config file:"
echo "  ${AWS_CONFIG_FILE}"


# ============================================================
# 10. Configure AWS profile
# ============================================================

echo
echo "------------------------------------------------------------"
echo "10. Configuring AWS profile: ${AWS_PROFILE}"
echo "------------------------------------------------------------"

echo
echo "You need your temporary AWS credentials."
echo
echo "The credentials normally consist of:"
echo "  AWS Access Key ID"
echo "  AWS Secret Access Key"
echo "  AWS Session Token"
echo
echo "These will be stored ONLY in:"
echo "  ${AWS_CREDENTIALS_FILE}"
echo
echo "They will NOT be stored in the Git repository."
echo

read -r -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID

read -r -s -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo

read -r -s -p "AWS Session Token: " AWS_SESSION_TOKEN
echo


# ============================================================
# 11. Write AWS credentials
# ============================================================

echo
echo "Writing credentials for profile '${AWS_PROFILE}'..."

# Remove an existing ai-profile block if present.
if grep -q "^\[${AWS_PROFILE}\]" "${AWS_CREDENTIALS_FILE}"; then

    awk -v profile="${AWS_PROFILE}" '
        BEGIN { skip=0 }
        $0 == "[" profile "]" {
            skip=1
            next
        }
        /^\[/ {
            skip=0
        }
        skip == 0 {
            print
        }
    ' "${AWS_CREDENTIALS_FILE}" > "${AWS_CREDENTIALS_FILE}.tmp"

    mv "${AWS_CREDENTIALS_FILE}.tmp" "${AWS_CREDENTIALS_FILE}"

fi


cat >> "${AWS_CREDENTIALS_FILE}" <<EOF

[${AWS_PROFILE}]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
aws_session_token = ${AWS_SESSION_TOKEN}
EOF

chmod 600 "${AWS_CREDENTIALS_FILE}"


# ============================================================
# 12. Configure AWS region
# ============================================================

echo
echo "Configuring AWS profile..."

# Remove existing profile configuration if present.
if grep -q "^\[profile ${AWS_PROFILE}\]" "${AWS_CONFIG_FILE}"; then

    awk -v profile="${AWS_PROFILE}" '
        BEGIN { skip=0 }
        $0 == "[profile " profile "]" {
            skip=1
            next
        }
        /^\[profile / {
            skip=0
        }
        skip == 0 {
            print
        }
    ' "${AWS_CONFIG_FILE}" > "${AWS_CONFIG_FILE}.tmp"

    mv "${AWS_CONFIG_FILE}.tmp" "${AWS_CONFIG_FILE}"

fi


cat >> "${AWS_CONFIG_FILE}" <<EOF

[profile ${AWS_PROFILE}]
region = ${AWS_REGION}
output = json
EOF

chmod 600 "${AWS_CONFIG_FILE}"


# ============================================================
# 13. Verify AWS credentials
# ============================================================

echo
echo "------------------------------------------------------------"
echo "11. Verifying AWS credentials"
echo "------------------------------------------------------------"

echo
echo "Running:"
echo "  aws sts get-caller-identity --profile ${AWS_PROFILE}"
echo

if aws sts get-caller-identity \
    --profile "${AWS_PROFILE}" \
    --region "${AWS_REGION}"
then

    echo
    echo "✓ AWS authentication successful"

else

    echo
    echo "ERROR: AWS authentication failed."
    echo
    echo "Check your temporary credentials and try again."
    exit 1

fi


# ============================================================
# 14. Export AWS profile for current shell
# ============================================================

export AWS_PROFILE="${AWS_PROFILE}"
export AWS_REGION="${AWS_REGION}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

echo
echo "AWS_PROFILE=${AWS_PROFILE}"
echo "AWS_REGION=${AWS_REGION}"


# ============================================================
# 15. Final verification
# ============================================================

echo
echo "============================================================"
echo "                 ENVIRONMENT READY"
echo "============================================================"

echo
echo "Python:"
python --version

echo
echo "pip:"
python -m pip --version

echo
echo "AWS CLI:"
aws --version

echo
echo "Terraform:"
terraform version

echo
echo "Python environment:"
echo "  ${VENV_DIR}"

echo
echo "Requirements:"
echo "  ${REQUIREMENTS_FILE}"

echo
echo "AWS profile:"
echo "  ${AWS_PROFILE}"

echo
echo "AWS credentials:"
echo "  ${AWS_CREDENTIALS_FILE}"

echo
echo "AWS config:"
echo "  ${AWS_CONFIG_FILE}"

echo
echo "AWS region:"
echo "  ${AWS_REGION}"

echo
echo "============================================================"
echo "                 AI ENGINEERING LAB READY"
echo "============================================================"
echo
```

