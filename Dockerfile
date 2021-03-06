FROM nvidia/cuda:9.0-cudnn7-runtime-ubuntu16.04
SHELL ["/bin/bash", "-c"]

# Source code
ADD . /app
WORKDIR /app
ENV PYTHONPATH=/app/deeplytough:$PYTHONPATH

# APT dependencies
RUN apt-get update && apt-get install -y \
    apt-utils \
    bzip2 \
    ca-certificates \
    git \
    curl \
    sysstat \
    wget \
    unzip \
    # for fpocket
    libnetcdf-dev && \
    apt-get clean

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-4.5.4-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /miniconda && \
    rm ~/miniconda.sh && \
    /miniconda/bin/conda clean -tipsy && \
    ln -s /miniconda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /miniconda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc
ENV PATH=/miniconda/bin:${PATH}

RUN conda update -y -q conda

# setup python 3 env
RUN conda create -y -n deeplytough python=3.6
RUN conda install -y -n deeplytough -c acellera -c psi4 -c conda-forge htmd=1.13.10
RUN apt-get -y install openbabel
RUN source activate deeplytough; \
    pip install --upgrade pip; \
    pip install --no-cache-dir -r /app/requirements.txt \
    pip install --ignore-installed llvmlite==0.28

# setup python 2 env
RUN conda create -y -n deeplytough_mgltools python=2.7
RUN conda install -y -n deeplytough_mgltools -c bioconda mgltools=1.5.6

# rot covariant convolutions (includes also the 'experiments' code)
RUN source activate deeplytough; \
    git clone https://github.com/mariogeiger/se3cnn && \
    cd se3cnn && \
    git reset --hard 6b976bea4ea17e1bd5655f0f030c6e2bb1637b57 && \
    mv experiments se3cnn; sed -i "s/exclude=\['experiments\*'\]//g" setup.py && \
    python setup.py install && \
    cd .. && \
    rm -rf se3cnn;
RUN source activate deeplytough; \
    git clone https://github.com/AMLab-Amsterdam/lie_learn && \
    cd lie_learn && python setup.py install && cd .. && rm -rf lie_learn

# fpocket2
RUN curl -LO https://netcologne.dl.sourceforge.net/project/fpocket/fpocket2.tar.gz && \
    tar -xvzf fpocket2.tar.gz && rm fpocket2.tar.gz && cd fpocket2 && \
    sed -i 's/\$(LFLAGS) \$\^ -o \$@/\$\^ -o \$@ \$(LFLAGS)/g' makefile && make && \
    mv bin/fpocket bin/fpocket2 && mv bin/dpocket bin/dpocket2 && mv bin/mdpocket bin/mdpocket2 && mv bin/tpocket bin/tpocket2
ENV PATH=/app/fpocket2/bin:${PATH}