rule count_const_sites:
    input:
        output_dir.joinpath("snp_analysis", "snippy-core", "cluster_{cluster}"),
    output:
        temp(output_dir.joinpath("ml_tree", "counts_cluster_{cluster}.txt")),
    message:
        "Counting constant site identities."
    params:
        cluster="{cluster}",
    log:
        log_dir.joinpath("snp_analysis", "count_const_sites", "cluster_{cluster}.log"),
    conda:
        "../../envs/snippy.yaml"
    container:
        "docker://staphb/snippy:4.6.0-SC2"
    threads: config["threads"]["other"]
    resources:
        mem_gb=config["mem_gb"]["other"],
    shell:
        """
snp-sites -C {input}/cluster_{params.cluster}.full.aln > {output}
        """


rule make_tree:
    input:
        output_dir.joinpath("snp_analysis", "snippy-core", "cluster_{cluster}"),
    output:
        tree=output_dir.joinpath("tree", "cluster_{cluster}", "newick_tree.txt"),
    container:
        "docker://andersenlab/vcf-kit:20200822175018b7b60d"
    conda:
        "../../envs/vcfkit.yaml"
    message:
        "Making tree..."
    log:
        log_dir.joinpath("making_tree_cluster_{cluster}.log"),
    threads: config["threads"]["vcfkit"]
    resources:
        mem_gb=config["mem_gb"]["vcfkit"],
    params:
        cluster="{cluster}",
        algorithm=config["tree"]["algorithm"],
    shell:
        """
vk phylo tree {params.algorithm} {input}/cluster_{params.cluster}.vcf > {output.tree} 2> {log}
        """


rule make_ml_tree:
    input:
        snippy_dir=output_dir.joinpath(
            "snp_analysis", "snippy-core", "cluster_{cluster}"
        ),
        const_sites=output_dir.joinpath("ml_tree", "counts_cluster_{cluster}.txt"),
    output:
        directory(output_dir.joinpath("ml_tree", "cluster_{cluster}")),
    container:
        "docker://staphb/iqtree2:2.2.2.6"
    conda:
        "../../envs/iqtree.yaml"
    message:
        "Making ML tree..."
    log:
        log_dir.joinpath("making_ML_tree_cluster_{cluster}.log"),
    threads: config["threads"]["iqtree"]
    resources:
        mem_gb=config["mem_gb"]["iqtree"],
    params:
        cluster="{cluster}",
    shell:
        """
mkdir -p {output}

NR_SAMPLES=$(grep -c '>' {input.snippy_dir}/cluster_{params.cluster}.aln)
if [ $NR_SAMPLES -le 2 ]
then
    echo "Not running IQ-tree, does not reach minimal of three samples" > {output}/iqtree_not_started_for_cluster.txt
else
    iqtree2 \
    -s {input.snippy_dir}/cluster_{params.cluster}.aln \
    -fconst $(<{input.const_sites}) \
    -nt {threads} \
    --prefix {output}/cluster_{params.cluster} \
    --seed 1 \
    --mem {resources.mem_gb}G 2>&1>{log}

    if [ ! -f {output}/cluster_{params.cluster}.treefile ]
    then
        echo "Treefile is missing, exiting with error now" >>{log}
        exit 1
    fi
fi
        """


rule get_dm:
    input:
        output_dir.joinpath("tree", "cluster_{cluster}", "newick_tree.txt"),
    output:
        output_dir.joinpath("tree", "cluster_{cluster}", "distance_matrix.csv"),
    message:
        "Getting distance matrix..."
    log:
        log_dir.joinpath("get_distance_matrix_cluster_{cluster}.log"),
    threads: config["threads"]["other"]
    resources:
        mem_gb=config["mem_gb"]["other"],
    params:
        dm=lambda wildcards: output_dir.joinpath(
            "tree", f"cluster_{wildcards.cluster}", "distance_matrix.tab"
        ),
    shell:
        """
python bin/newick2dm.py -i {input} -o {output}
        """


rule get_snp_matrix:
    input:
        output_dir.joinpath("snp_analysis", "snippy-core", "cluster_{cluster}"),
    output:
        snp_matrix=output_dir.joinpath("tree", "cluster_{cluster}", "snp_matrix.csv"),
    container:
        "docker://staphb/snp-dists:0.8.2"
    conda:
        "../../envs/snp_dists.yaml"
    message:
        "Making SNP matrix"
    log:
        log_dir.joinpath("snp_matrix_cluster_{cluster}.log"),
    threads: config["threads"]["other"]
    resources:
        mem_gb=config["mem_gb"]["other"],
    params:
        cluster="{cluster}",
    shell:
        """
snp-dists -c {input}/cluster_{params.cluster}.full.aln 1>{output.snp_matrix} 2>{log}
        """
