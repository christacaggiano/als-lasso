
### ID for processing in parallel 
ID=$(($SGE_TASK_ID+48))

### setting file names and IDS
R1="../panel/als_v1/fastq/Marco-5842/"$ID"/NcfT_A"$SGE_TASK_ID"_S"$ID"_L004_R1_001.fastq.gz"
R2="../panel/als_v1/fastq/Marco-5842/"$ID"/NcfT_A"$SGE_TASK_ID"_S"$ID"_L004_R3_001.fastq.gz"
I1="../panel/als_v1/fastq/Marco-5842/"$ID"/NcfT_A"$SGE_TASK_ID"_S"$ID"_L004_R2_001.fastq.gz"
OUTPUT="../panel/als_v1/mapped_bsbolt/"$ID
METH="../panel/als_v1/bsbolt_meth/"$ID
TEMP="../panel/als_v1/temp/"$ID

################################################################

### doing QC for fastqs 
fastqc $R1 $R2 --outdir "../panel/als_v1/fastq/Marco-5842/"$SGE_TASK_ID
# 
################################################################

### for UMIs

# umi_tools extract --bc-pattern=NNNNNNNNN --stdin $I1 --read2-in $R1 --stdout $TEMP"_R1_umi.fastq.gz" --read2-stdout --log $TEMP"_umi.log"
# umi_tools extract --bc-pattern=NNNNNNNNN --stdin $I1 --read2-in $R2 --stdout $TEMP"_R2_umi.fastq.gz" --read2-stdout --log $TEMP"_umi.log"


################################################################

### you will likely need to trim. my data needed a hardtrim, but usually trim_galore will 
### be able to automatically trim illumina adpaters if it's a simple case so you can try 
### trim_galore -o <output> <file_name> 
trim_galore -o "../panel/als_v1/temp/" --hardtrim3 135 $TEMP"_R1_umi.fastq.gz"
trim_galore -o "../panel/als_v1/temp/" --hardtrim5 135 $TEMP"_R2_umi.fastq.gz"

# ############################################################


### aligning step, you need a bisulfite converted hg38 genome generated with the command 
### bsbolt Index -G {fasta reference} -DB {database output}
### this step takes a very long time, but you will ony have to do this once 

### after you have a bisulfite genome you can do this step
python -m bsbolt Align -t 8 -OT 8 -DB bsbolt_db -F1 $TEMP"_R1_umi.135bp_3prime.fq.gz" -F2 $TEMP"_R2_umi.135bp_5prime.fq.gz" -O $OUTPUT > $OUTPUT"_log.txt"

### fixmates to prepare for duplicate removal, use -p to disable proper pair check
samtools fixmate -p -m $OUTPUT".bam" $OUTPUT".fixmates.bam" 

### sort bam by coordinates for duplicate calling
samtools sort -@ 4 -o $OUTPUT".sorted.bam" $OUTPUT".fixmates.bam"
samtools index $OUTPUT".sorted.bam"


# ###############################################################
### samtools for positional deduplication 

# umi_tools dedup -I $OUTPUT"_r1_only.sorted.bam" --output-stats $OUTPUT".r1_umi_dup.stats.txt" -S $OUTPUT".r1_umi_dedup.bam"

samtools flagstat -@ 4 $OUTPUT".sorted.bam"
# umi_tools dedup -I $OUTPUT".sorted.bam" --paired -S $OUTPUT".umi_dedup.bam"
samtools flagstat -@ 4 $OUTPUT".umi_dedup.bam"
samtools index -@ 4 $OUTPUT".umi_dedup.bam"

# ############################################################

### call methylation 
python -m bsbolt CallMethylation -BG -CG -remove-ccgg -I $OUTPUT".umi_dedup.bam" -DB bsbolt_db -O $METH -t 4 




