#!/usr/bin/env nextflow

//
// ALIGNMENT
//
// For all modules here:
// A when clause condition is defined in the conf/modules.config to determine if the module should be run

include { BOWTIE2_ALIGN                     } from "../../../modules/nf-core/modules/bowtie2/align/main"
include { BWA_MEM as BWAMEM1_MEM            } from '../../../modules/nf-core/modules/bwa/mem/main'
include { SNAPALIGNER_ALIGN as SNAP_ALIGN   } from '../../../modules/nf-core/modules/snapaligner/align/main'


workflow ALIGNMENT {
    take:
        ch_reads            // channel: [mandatory] meta, reads
        ch_aligner_index    // channel: [mandatory] aligner index
        sort                // boolean: [mandatory] true -> sort, false -> don't sort

    main:

        ch_versions = Channel.empty()

        // Align fastq files to reference genome and (optionally) sort
        BOWTIE2_ALIGN(ch_reads, ch_aligner_index, false, sort) // if aligner is bowtie2
        BWAMEM1_MEM  (ch_reads, ch_aligner_index, sort)        // If aligner is bwa-mem
        SNAP_ALIGN   (ch_reads, ch_aligner_index)              // If aligner is snap

        ch_versions = ch_versions.mix(
            BOWTIE2_ALIGN.out.versions,
            BWAMEM1_MEM.out.versions,
            SNAP_ALIGN.out.versions
        )

        // Get the bam files from the aligner
        // Only one aligner is run
        ch_bam = Channel.empty()
        ch_bam = ch_bam.mix(
            BOWTIE2_ALIGN.out.bam,
            BWAMEM1_MEM.out.bam,
            SNAP_ALIGN.out.bam,
        )
        ch_cleaned_bam = ch_bam.map { meta, bam ->
            [ meta.findAll { !(it.key in ['readgroup', 'library']) }, bam ]
        }.groupTuple()

        ch_bai = Channel.empty()
        ch_bai= ch_bai.mix(
            SNAP_ALIGN.out.bai,
        )
        ch_cleaned_bai = ch_bai.map { meta, bai ->
            [ meta.findAll { !(it.key in ['readgroup', 'library']) }, bai ]
        }.groupTuple()

    emit:
        bam      = ch_cleaned_bam // channel: [ [meta], bam  ]
        bai      = ch_cleaned_bai // channel: [ [meta], bai  ]
        versions = ch_versions    // channel: [ versions.yml ]
}
