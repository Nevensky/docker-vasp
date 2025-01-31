# VASP with GNU compilers + openmpi + scalapack + hdf5 + libxc + miniconda python3 with py4vasp
# This Dockerfile asumes you have an entrypoint.sh script and makefile.include in the same directory
# and a subdirectory /vasp which contains either vasp.6.4.3.tgz or vasp.6.4.3+vtsttools.tgz 
# as well as potpaw_PBE.64.tgz and vdw_kernel.bindat.tgz archives
# When running the container it is recommended to bind the container /tmp directory
# to your work directory (usually /scratch, /tmp or /home/YOUR_USER/whichever/directory/you/like)

FROM ubuntu:22.04
# change shell to bash (not neccessary but useful)
RUN rm /bin/sh && ln -s /bin/bash /bin/sh 

LABEL org.opencontainers.image.authors="Dr. Neven Golenić <neven.golenic@gmail.com>"

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Set default number of OpenMP threads
ENV OMP_NUM_THREADS=1

# Discourage apt from trying to talk to you
ARG DEBIAN_FRONTEND=noninteractive

# Copy default entryppint bash script and ensure it is executable
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends apt-utils make rsync patch htop wget nano vim less git ca-certificates && \
    apt-get install -y --no-install-recommends g++ gfortran\
                       libopenblas-dev \
                       libscalapack-mpi-dev \
                       openssh-server \
                       libopenmpi-dev openmpi-common openmpi-bin \
                       libfftw3-dev \
                       libhdf5-dev \
                       autoconf automake libtool m4
# apt-get cleanup
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# Build libxc
WORKDIR /opt
RUN git clone -b 6.2.2 https://gitlab.com/libxc/libxc.git libxc.6.2.2
WORKDIR /opt/libxc.6.2.2

RUN aclocal
RUN libtoolize
# RUN autoconf -i
RUN autoreconf -fi
RUN mkdir -p libxc
RUN ./configure --prefix=/opt/libxc.6.2.2 --disable-fhc CC=gcc FC=mpifort
RUN make -j$(nproc --all)
# RUN make check # commented out as it resuls in failed build; unit-tests fail when compiling with the --disable-fhc flag
RUN make install

ENV PATH="$PATH:/opt/libxc.6.2.2/bin"


WORKDIR /opt

# Build VASP 
# Comment out if you need VTST tools
# ADD ./vasp/vasp.6.4.3.tgz . 
# Uncomment if you need VTST tools 2.04
ADD ./vasp/vasp.6.4.3+vtsttools.tgz .
RUN mv vasp.6.4.3+vtsttools vasp.6.4.3

WORKDIR vasp.6.4.3

# RUN cp arch/makefile.include.gnu_omp makefile.include
COPY ./makefile.include .

RUN make DEPS=1 -j$(nproc --all) std

# Export VASP to path
ENV PATH="$PATH:/opt/vasp.6.4.3/bin/"

# Copy pseudopotential files and vdW kernel to /tmp
WORKDIR /tmp
RUN mkdir -p pseudo
ADD ./vasp/potpaw_PBE.64.tgz ./pseudo
ADD ./vasp/vdw_kernel.bindat.tgz .

# Add non root user
RUN useradd -ms /bin/bash vasp
RUN chown vasp:vasp /tmp

# Install Miniconda in /opt/miniconda3
WORKDIR /opt
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O miniconda.sh; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    bash miniconda.sh -b -p /opt/miniconda3 && \
    rm miniconda.sh

# Change ownership of Miniconda directory to vasp
RUN chown -R vasp:vasp /opt/miniconda3

# Change to non-root user
USER vasp

# Ensure .custom_bashrc exists
RUN touch ~/.custom_bashrc

# Add Miniconda to PATH and configure .bashrc
ENV PATH="/opt/miniconda3/bin:$PATH"

# Set up .bashrc
RUN echo "export PATH=/opt/miniconda3/bin:\$PATH" >> ~/.custom_bashrc && \
    echo "source /opt/miniconda3/etc/profile.d/conda.sh" >> ~/.custom_bashrc && \
    cat "/opt/miniconda3/etc/profile.d/conda.sh" >> ~/.custom_bashrc && \
    echo "conda activate base" >> ~/.custom_bashrc

# Ensure .custom_bashrc is sourced so that conda commands below work
RUN source ~/.custom_bashrc

# # Ensure this is sourced in every shell session
# RUN echo "source .custom_bashrc" >> ~/.bashrc

WORKDIR /opt/miniconda3/bin
# Install Python packages
RUN ./conda init bash && \
    ./conda install -y -c conda-forge numpy matplotlib scipy jupyter py4vasp && \
    ./conda clean -afy
# removed pylibxc=6.2.2 from conda (takes up more space and is not connected to the compiled (above) libxc version)

WORKDIR /opt/miniconda3
# Clean up unnecessary files from Miniconda
RUN find ./ -follow -type f -name '*.a' -delete && \
    find ./ -follow -type f -name '*.js.map' -delete

# Add alias for a quick vasp run (local)
RUN echo "alias vs=\"mpirun -np $(nproc --all) vasp_std\"" >> ~/.custom_bashrc
RUN echo "alias vasp_rm=\"rm -f CHG CHGCAR CONTCAR STOPCAR DOSCAR DYNMAT EIGENVAL IBZKPT OPTIC OSZICAR OUTCAR PROCAR PCDAT WAVECAR XDATCAR PARCHG vasprun.xml REPORT wannier90.win wannier90_band.gnu wannier90_band.kpt wannier90.chk wannier90.wout vaspout.h5 PENALTYPOT HILLSPOT ML_LOGFILE ML_ABN ML_FFN ML_HIS ML_REG\"" >> ~/.custom_bashrc


# Set up default mount point (for Docker only, Singularity handles this differently)
VOLUME /tmp
WORKDIR /tmp

# In case one wants to use the container dirrectly "akin to" a vasp binary
# CMD ["mpirun", "-np $(nproc --all)", "--mca", "btl_vader_single_copy_mechanism", "none", "/opt/vasp.6.4.3/bin/vasp_std"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Not needed since we have an entrypoint, but useful as a fallback
CMD ["/bin/bash"]
