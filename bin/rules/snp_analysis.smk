import yaml


def get_mapped_per_cluster(cluster):
    with open(checkpoints.preclustering.get(**cluster).output[0]) as file:
        SAMPLE_CLUSTERS = yaml.safe_load(file)
    SELECTED_SAMPLES = []
    for sample, sample_cluster in SAMPLE_CLUSTERS.items():
        if str(sample_cluster) == str(cluster):
            SELECTED_SAMPLES.append(sample)
    return expand(
        output_dir.joinpath("snp_analysis", "cluster_{cluster}", "{sample}"),
        sample=SELECTED_SAMPLES,
        allow_missing=True,
    )


rule snp_analysis:
    input:
        r1=lambda wildcards: SAMPLES[wildcards.sample]["R1"],
        r2=lambda wildcards: SAMPLES[wildcards.sample]["R2"],
        ref=output_dir.joinpath("ref_genomes_used/cluster_{cluster}/ref_genome.fasta"),
    output:
        res=directory(
            output_dir.joinpath("snp_analysis", "cluster_{cluster}", "{sample}")
        ),
        bam=output_dir.joinpath("snp_analysis", "cluster_{cluster}", "{sample}", "snps.bam"),
        vcf=output_dir.joinpath("snp_analysis", "cluster_{cluster}", "{sample}", "snps.vcf"),
        aligned_fa=output_dir.joinpath("snp_analysis", "cluster_{cluster}", "{sample}", "snps.aligned.fa"),
    message:
        "Running snippy on sample {wildcards.sample}."
    log:
        log_dir.joinpath("snp_analysis", "cluster_{cluster}", "snippy_{sample}.log"),
    container:
        "docker://staphb/snippy:4.6.0-SC2"
    conda:
        "../../envs/snippy.yaml"
    threads: config["threads"]["snippy"]
    resources:
        mem_gb=config["mem_gb"]["snippy"],
    params:
        mincov=10,
        minfrac=0.9,
        minqual=100,
        mapqual=60,
        basequal=13,
        maxsoft="x",
    shell:
        """
snippy --cpus {threads} \
    --outdir {output} \
    --ref {input.ref} \
    --R1 {input.r1} \
    --R2 {input.r2} \
    --report \
    --force 2>&1>{log}

samtools stats {output.res}/snps.bam 1>{output.stats} 2>>{log}
        """


rule snp_core:
    input:
        samples=get_mapped_per_cluster,
        ref=output_dir.joinpath("ref_genomes_used/cluster_{cluster}/ref_genome.fasta"),
    output:
        directory(output_dir.joinpath("snp_analysis/snippy-core/cluster_{cluster}")),
    message:
        "Getting SNP core."
    log:
        log_dir.joinpath("snp_analysis", "snippy_core", "cluster_{cluster}.log"),
    conda:
        "../../envs/snippy.yaml"
    container:
        "docker://staphb/snippy:4.6.0-SC2"
    threads: config["threads"]["snippy"]
    resources:
        mem_gb=config["mem_gb"]["snippy"],
    shell:
        """
mkdir -p {output}
snippy-core --ref {input.ref} --prefix {output}/core_snps {input.samples} 2>&1> {log}
        """
