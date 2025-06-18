# ==================================================
# Final Containerfile
# ==================================================

# Use the minimal S2I Python 3.11 image as our base
FROM quay.io/sclorg/python-311-c9s:c9s

###########################
# 1. Install Core OS Packages
###########################

# Switch to root to use yum
USER 0

# Copy the list of essential OS packages
COPY --chown=1001:0 os-packages.txt /tmp/os-packages.txt

# Update the system, enable EPEL, and install packages needed for building Python libraries
RUN echo "tsflags=nodocs" >> /etc/yum.conf && \
    yum -y update && \
    yum install -y yum-utils && \
    yum-config-manager --enable crb && \
    yum install -y https://download.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    yum install -y $(cat /tmp/os-packages.txt) && \
    # Clean up to keep the layer small
    yum -y clean all --enablerepo='*' && \
    rm -rf /var/cache/dnf /tmp/os-packages.txt && \
    find /var/log -type f -name "*.log" -exec rm -f {} \;

#############################################
# 2. Install Python Packages for CrewAI App
#############################################

# Copy your new, consolidated requirements file
COPY --chown=1001:0 requirements.txt /tmp/requirements.txt

# You will need a simple start-notebook.sh script in your directory
# Or copy it from one of the other projects we discussed
COPY --chown=1001:0 start-notebook.sh /opt/app-root/bin/start-notebook.sh

# Install all Python packages and fix permissions in a single layer
RUN pip install --no-cache-dir --upgrade pip && \
    # CRITICAL FIX: First, install a small, CPU-only version of PyTorch to avoid storage errors
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    # Now, install all other application dependencies from our requirements file
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    # Clean up the requirements file
    rm /tmp/requirements.txt && \
    # Fix permissions for the OpenShift environment
    PYTHON_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])") && \
    chown -R 1001:0 /opt/app-root && \
    fix-permissions "$PYTHON_SITE_PACKAGES" -P

#############################################
# 3. Final Configuration
#############################################

# Switch to the default non-root user
USER 1001

# Set the final working directory for the notebook
WORKDIR /opt/app-root/src

# Expose the Jupyter port
EXPOSE 8888

# Set the entrypoint to start the notebook server
ENTRYPOINT ["start-notebook.sh"]
