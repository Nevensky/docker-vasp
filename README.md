# VASP Docker Image with VTST Tools, LibXC and Miniconda3

This repository provides a Docker setup for building a containerized version of VASP (Vienna Ab-initio Simulation Package), optionally with **Transition State Tools for VASP**, as well as **Libxc**, for a vast selection of functionals and **Miniconda3**, ensuring easy access to Python within the containerized environment. Note that the Dockerfile in its current form is version specific and is tailored towards VASP version **6.4.3**.

This setup ensures portability, reproducibility, and an easy way to run VASP with Python support across different environments. By leveraging Docker and Singularity, you can seamlessly run your simulations both locally and on HPC clusters.

## Prerequisites

Before building the Docker image, you must provide your own VASP source code archive. This is due to licensing restrictions.

Place one of the following tarballs in the `vasp` subdirectory:

- `vasp.6.4.3+vtsttools.tgz` (for VASP with VTST tools)
- `vasp.6.4.3.tgz` (for standard VASP)

as well as

- `vdw_kernel.bindat.tgz` (kernel for van der Waals functionals)
- `potpaw_PBE.64.tgz` (PBE pseudopotential library)


**Note:** The directory structure should look like this before building:

```
.
├── Dockerfile
├── entrypoint.sh
├── makefile.include
├── vasp
│   ├── vasp.6.4.3+vtsttools.tgz   # or vasp.6.4.3.tgz
│   ├── potpaw_PBE.64.tgz
│   ├── vdw_kernel.bindat.tgz
└── (non essential repository files)
```

## Building the Docker Image

To build the Docker image, run the following command in the directory containing the `Dockerfile`:

```sh
docker build -t vasp:6.4.3 .
```

This will create a Docker image named `vasp:6.4.3` with VASP, Libxc, and Miniconda3 installed.

## Running VASP with Docker

To run the container interactively, use:

```sh
docker run --rm -it vasp:6.4.3
```

However in most cases you will need access to your local files inside your container, therefore it is better to use:

```sh
docker run --rm -it -v $(pwd):/tmp vasp:6.4.3 
```

The `-v` flag mounts the current directory `$(pwd) inside the container at `/tmp`, allowing you to run VASP on your input files.

To execute VASP dirrectly inside the container, you can use:

```sh
docker run --rm -v $(pwd):/tmp vasp:6.4.3 vasp_std
```

This is useful when you only need to run VASP in a single directory once.

**Note:** The `--rm` flag removes the container after use which is usually good practice in order to save storage space, however if for some reason you would like to reuse the container in the future (for example if you installed extra python packages and don't want to do this every time all over again) skip this flag.

## Transferring the Docker Image to an HPC Environment

Since many HPC environments do not support Docker directly, you need to convert the Docker image to a format compatible with **Singularity (Apptainer)**.

### Exporting the Docker Image

On your local machine, save the Docker image as a `.tar` file:

```sh
docker save -o vasp-643.tar vasp:6.4.3
```

Transfer this file to your HPC cluster using `scp` or `rsync`:

```sh
scp vasp-643.tar username@hpc.example.com:/path/to/transfer/
```

### Importing to Singularity on HPC

Once on the HPC system, load **Singularity (Apptainer)** and import the image:

```sh
singularity build --fakeroot vasp-643.sif docker-archive://vasp-643.tar
```

**Note:** Be careful to export `SINGULARITY_TMPDIR` and `SINGULARITY_CACHEDIR` variables to a directory for which you have adequate read/write permissions, usually `/var/tmp` is a safe choice.

### Running VASP with Singularity on HPC

To run an interactive session:

```sh
singularity run vasp-643.sif
```

To execute VASP within the Singularity container:

```sh
singularity exec vasp-643.sif vasp_std
```

To mount a local working directory inside the container `/tmp` folder for your simulations:

```sh
singularity run --bind /scratch:/tmp vasp-643.sif
```

```sh
singularity exec --bind /scratch:/tmp vasp-643.sif vasp_std
```

This assumes your simulation directory is placed inside `/scratch` which is often reserved as a fast local storage on a compute node, but make sure that this is also the case for your HPC enviroment (read the documentation).

## Questions? Bugs?
For any issues or questions, feel free to open an issue in this repository.

---

**License:** Note that VASP is a licensed software, and you are responsible for obtaining the appropriate license before using this container.

