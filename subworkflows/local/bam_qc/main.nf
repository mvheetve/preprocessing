#!/usr/bin/env nextflow

include { PICARD_COLLECTMULTIPLEMETRICS } from "../../../modules/nf-core/picard/collectmultiplemetrics/main"
include { BAM_STATS_SAMTOOLS            } from "../../nf-core/bam_stats_samtools/main"

workflow BAM_QC {
    take:
        ch_bam_bai   // channel: [mandatory] [meta, bam, bai]
        ch_fasta_fai // channel: [mandatory] [meta2, fasta, fai]

    main:
        ch_versions = Channel.empty()
        ch_metrics  = Channel.empty()

        ch_fasta = ch_fasta_fai.map {meta, fasta, fai -> fasta             }.collect()
        ch_meta_fai   = ch_fasta_fai.map {meta, fasta, fai -> [meta, fai]  }.collect()
        ch_meta_fasta = ch_fasta_fai.map {meta, fasta, fai -> [meta, fasta]}.collect()


        // Collect multiple metrics
        // PICARD_COLLECTMULTIPLEMETRICS( [meta, bam], fasta)
        PICARD_COLLECTMULTIPLEMETRICS( ch_bam_bai, ch_meta_fasta, ch_meta_fai )
        ch_metrics  = ch_metrics.mix(PICARD_COLLECTMULTIPLEMETRICS.out.metrics)
        ch_versions = ch_versions.mix(PICARD_COLLECTMULTIPLEMETRICS.out.versions)

        // SUBWORKFLOW: bam_stats_samtools
        // Run samtools QC modules
        // BAM_STATS_SAMTOOLS([meta, bam, bai])
        BAM_STATS_SAMTOOLS(ch_bam_bai, ch_fasta)

        ch_metrics = ch_metrics.mix(
            BAM_STATS_SAMTOOLS.out.stats,
            BAM_STATS_SAMTOOLS.out.flagstat,
            BAM_STATS_SAMTOOLS.out.idxstats
        ).groupTuple().map { meta, metrics -> [meta, metrics.flatten()] }
        ch_metrics.dump(tag: "BAM QC: metrics", {FormattingService.prettyFormat(it)})
        ch_versions = ch_versions.mix(BAM_STATS_SAMTOOLS.out.versions)

    emit:
        metrics  = ch_metrics   // [[meta, metrics], [...], ...]
        versions = ch_versions  // [versions]
}
