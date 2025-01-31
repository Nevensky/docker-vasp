#!/bin/bash
set -e  # exits immediately if a command exits with a non-zero status


# Source .custom_bashrc (in case not properly sourced from Dockerfile)
if [ -f .custom_bashrc ]; then
    source ~/.custom_bashrc
fi

# Prints out versions of the main codes in this container build
vasp_std -v
xc-info --version | head -n1
conda --version && python --version
python -c "import py4vasp; print('Py4VASP ',py4vasp.__version__)"

# Prints out number of OpenMP threads (default is 1)
echo "Number of OpenMP threads: $OMP_NUM_THREADS"

# For local developement starts a jupyter notebook (add -p 8888:8888 in docker run to expose port)
# nohup jupyter notebook --no-browser --port=8888 --ip=0.0.0.0 --allow-root --NotebookApp.token='' --NotebookApp.password='' --notebook-dir=/tmp & disown


# Ensure we start in the /tmp of the container
cd /tmp

echo "Current working directory: $(pwd)"
echo "Tip: Mount your local directory with '--bind /your/path:/tmp' (Singularity) or '-v /your/path:/tmp' (Docker)."

# Execute the provided command or start a shell
exec "$@"

