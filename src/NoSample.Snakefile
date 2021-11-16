import os

#grab SAMPLE name from vcf input
SAMPLE = str(config['input_vcf']).split('.vcf')[0]
# logic to parse ped for families
# can either be  multiple families (a list) in the yaml as below
# need to grab the family names from it
# better to obtain family name from ped file directly to save one step.
if type(config['ped']) == list:
	PEDfile = [x.split('.ped')[0].split('/')[-1] for x in config['ped']]
	PEDbase = '/'.join(config['ped'][0].split('.ped')[0].split('/')[:-1]) + '/'
# otherwise just one family can be provided, which would be a str as below:
else:
	PEDfile = config['ped'].split('.ped')[0].split('/')[-1]
	PEDbase = '/'.join(config['ped'].split('.ped')[0].split('/')[:-1]) + '/'

if PEDbase == '/':
	PEDbase = ''

# if type(config['family_name']) == str:
# 	family_name_con = config['family_name']
# else:
# 	family_name_con = '|'.join(config['family_name'])

def pick():
	# modifies VEP call to either pick most canonical tx or
	# return all tx possibilities
	if config['pick'].upper() == 'CANONICAL':
		out = '--pick_allele_gene  --pick_order canonical, tsl, biotype, ccds, length '
	if config['pick'].upper() == 'ALL':
		out = '--flag_pick_allele_gene '
	return(out)

# import regions
REGIONS_file = config['regions']
if '/home/$USER' in REGIONS_file:
	REGIONS_file = os.environ['HOME'] + REGIONS_file.split('$USER')[-1]
REGIONS = open(REGIONS_file).readlines()
REGIONS = [r.strip() for r in REGIONS]
MT_CONTIGS="MT,GL000207.1,GL000226.1,GL000229.1,GL000231.1,GL000210.1,GL000239.1,GL000235.1,GL000201.1,GL000247.1,GL000245.1,GL000197.1,GL000203.1,GL000246.1,GL000249.1,GL000196.1,GL000248.1,GL000244.1,GL000238.1,GL000202.1,GL000234.1,GL000232.1,GL000206.1,GL000240.1,GL000236.1,GL000241.1,GL000243.1,GL000242.1,GL000230.1,GL000237.1,GL000233.1,GL000204.1,GL000198.1,GL000208.1,GL000191.1,GL000227.1,GL000228.1,GL000214.1,GL000221.1,GL000209.1,GL000218.1,GL000220.1,GL000213.1,GL000211.1,GL000199.1,GL000217.1,GL000216.1,GL000215.1,GL000205.1,GL000219.1,GL000224.1,GL000223.1,GL000195.1,GL000212.1,GL000222.1,GL000200.1,GL000193.1,GL000194.1,GL000225.1,GL000192.1,NC_007605"

def list_duplicates(seq):
  seen = set()
  seen_add = seen.add
  # adds all elements it doesn't know yet to seen and all other to seen_twice
  seen_twice = set( x for x in seq if x in seen or seen_add(x) )
  # turn the set into a list (as requested)
  return list( seen_twice )

# if not config['family_name']:
# #if (config['family_name']) == '':
# 	Family_Name = list()
# 	with open(config['ped']) as PED_file:
# 		for line in PED_file:
# 			if line.startswith("#"):
# 				continue
# 			else:
# 				Family_Name.append(line.split("\t")[0])
# 	Family_Name = list_duplicates(Family_Name)
# # elif type(config['family_name']) == str:
# # 	Family_Name = config['family_name']
# else:
# 	Family_Name = config['family_name']
# 	#Family_Name = '|'.join(config['family_name'])
#
# #if sampleid field has "-", convert it to "_", because gemini converts "-" this to "_".
# SampleID = list()
# #Family_Name = list()
# with open(config['ped']) as PED_file:
# 	for line in PED_file:
# 		if line.startswith("#"):
# 			continue
# 		else:
# #			Family_Name.append(line.split("\t")[0])
# 			SampleID.append(line.split("\t")[1].replace("-", "_"))
#print(Family_Name)
#print(SampleID)
#unique values of family_name
#Family_Name = list(set(Family_Name))
#print(Family_Name)
#name = '|'.join(open({config['ped']}).readlines().split('\t')[1])

# set global Snakemake wildcard constraints
wildcard_constraints:
	sample=SAMPLE,
	region = '|'.join(REGIONS),
#	region = '^[0-9a-zA-Z]+:\d+-\d+'
#	family_name=family_name_con,
#	family_name = '|'.join(Family_Name),
#	sampleid = '|'.join(SampleID)

if config['genomeBuild'].upper() in ['GRCH37', 'HG19']:
	config['ref_genome'] = '/data/OGL/resources/1000G_phase2_GRCh37/human_g1k_v37_decoy.fasta'
	config['vcfanno_conf'] = '/home/$USER/git/variant_prioritization/src/vcfanno_v4.conf'
elif config['genomeBuild'].upper() in ['GRCH38', 'HG38']:
	config['ref_genome'] = '/data/OGL/resources/genomes/GRCh38/GRCh38Decoy2.fa'
#	config['vcfanno_conf'] = '/home/$USER/git/variant_prioritization/src/vcfanno_v4.GRCh38.conf'
else:
	print("ref_genome is ", config['ref_genome'])
	print("vcfanno_conf is ", config['vcfann_conf'])


rule all:
	input:
		#expand('{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz', sample=SAMPLE),
		#expand('temp/{sample}.spliceai.new.vcf.depot.merged', sample=SAMPLE),
		expand('{sample}.squirls.tsv.gz', sample=SAMPLE)


if config['datatype'].upper() in ["PANEL", "EXOME", "WES"]:
	localrules: n_split_vcf
	#localrules: vcfanno2
	localrules: merge_sample_vcf
	#localrules: sortGemini
	#localrules: bcftools_norm
else:
	localrules: n_split_vcf

rule n_split_vcf:
	input:
		vcf = config['input_vcf']
	output:
		slivar = temp('temp/{sample}__{region}.slivar.vcf.gz'),
		slivar_index = temp('temp/{sample}__{region}.slivar.vcf.gz.tbi'),
		vcf = temp('temp/{sample}__{region}.vcf.gz'),
		index = temp('temp/{sample}__{region}.vcf.gz.tbi')
	shell:
		"""
		export REF_CACHE=/lscratch/$SLURM_JOB_ID/
		module load {config[samtools_version]}
		if [[ {wildcards.region} != "MT_contigs" ]]; then
			bcftools view --threads 8 -Oz -r {wildcards.region} {input.vcf} -o {output.slivar}
			tabix -f -p vcf {output.slivar}
			/data/OGL/resources/git/slivar expr -v {output.slivar} -g /data/OGL/resources/git/gnomad.hg38.genomes.v3.fix.zip | bgzip -@ 8 > {output.vcf}
		else
			bcftools view --threads 8 -Oz -r {MT_CONTIGS} {input.vcf} -o {output.slivar}
			tabix -f -p vcf {output.slivar}
			/data/OGL/resources/git/slivar expr -v {output.slivar} -g /data/OGL/resources/git/gnomad.hg38.genomes.v3.fix.zip | bgzip -@ 8 > {output.vcf}
		fi
		tabix -f -p vcf {output.vcf}
		"""

# if config['gatk3'] == 'TRUE':
# 	localrules: vt_bgzip_and_tabix_vcf
# 	rule vt_bgzip_and_tabix_vcf:
# 		input:
# 			'temp/{sample}__{region}.vcf.gz'
# 		output:
# 			vcf = temp('temp/vt.{sample}__{region}.vcf.gz'),
# 			index = temp('temp/vt.{sample}__{region}.vcf.gz.tbi')
# 		shell:
# 			"""
# 			export REF_CACHE=/lscratch/$SLURM_JOB_ID/
# 			module load {config[samtools_version]}
# 			module load {config[vt_version]}
# 			zcat {input} \
# 				| sed 's/ID=AD,Number=./ID=AD,Number=R/' \
# 				| vt decompose -s - \
# 				| vt normalize -r {config[ref_genome]} - \
# 				| bgzip -c > {output.vcf}
# 			tabix -f -p vcf {output.vcf}
# 			"""
# else:
# 	localrules: bcftools_norm
# 	rule bcftools_norm:
# 		input:
# 			'temp/{sample}__{region}.vcf.gz'
# 		output:
# 			vcf = temp('temp/vt.{sample}__{region}.vcf.gz'),
# 			index = temp('temp/vt.{sample}__{region}.vcf.gz.tbi')
# 		threads: 8
# 		shell:
# 			"""
# 			module load {config[samtools_version]}
# 			bcftools norm --multiallelics -any --output-type u --no-version {input} \
# 				| bcftools norm --check-ref s --fasta-ref {config[ref_genome]} --output-type u --no-version - \
# 				| bcftools norm --threads $(({threads}-2)) -d exact --output-type z -o {output.vcf}
# 			tabix -f -p vcf {output.vcf}
# 			"""

#-e "s|1/.|0/1|" -e "s|./1|0/1|" \ 2/14/2020, removed this for GATK combineVariants
# 		| sed 's/ID=AC,Number=./ID=AC,Number=A/' \ 1/20/20 vcf-merge of freebayes had problem for one of the position with 6 variants. GATK combine worked.
# freebayes vcf fixed by vt immediately after freebayes.
# vt normalize did not work as well as bcftools norm, which keeps all formats fields and properly decompose AF and AQ in the INFO field.

# localrules: intervar_evidence
# rule intervar_evidence:
# 	input:
# 		vcf = config['input_vcf']
# 	output:
# 		evidenceInput = temp('temp/evidence.input'),
# 		InterVarEvidence = temp('temp/InterVarEvidence.txt')
# 	shell:
# 		"""
# 		module load {config[R_version]}
# 		# module load {config[samtools_version]}
# 		module load {config[InterVar_version]}
# 		Rscript /home/$USER/git/variant_prioritization/src/intervar_evidence.R /data/OGL/resources/OGLvariantsClassification.xlsx {output.evidenceInput}
# 		# bcftools norm --check-ref s --fasta-ref {config[ref_genome]} --output-type v evidence.input  # needs true vcf style file for normalizaiton.
# 		convert2annovar.pl -format vcf4old {output.evidenceInput} -includeinfo | cut -f 1,2,4,5,8,13 > {output.InterVarEvidence}
# 		"""

#localrules: annovar_intervar
rule annovar_intervar:
	input:
		vcf = 'temp/{sample}__{region}.vcf.gz',
		index = 'temp/{sample}__{region}.vcf.gz.tbi',
		#InterVarEvidence = 'temp/InterVarEvidence.txt'
	output:
		avinput = temp('temp/{sample}__{region}.avinput'),
		annovar_out = temp('temp/{sample}__{region}.avinput.multianno.txt'),
		intervar_out = temp('temp/{sample}__{region}.avinput.multianno.txt.intervar')
	threads: 4
	shell:
		"""
		module load {config[annovar_version]}
		convert2annovar.pl -format vcf4old {input.vcf} -includeinfo --outfile {output.avinput}
		if [[ {config[genomeBuild]} == "GRCh38" ]]; then
			ver=hg38
		else
			ver=hg19
		fi
		table_annovar.pl {output.avinput} \
			$ANNOVAR_DATA/$ver \
			-buildver $ver \
			-remove \
			-out {output.avinput} \
			--protocol refGene,esp6500siv2_all,1000g2015aug_all,avsnp147,dbnsfp33a,clinvar_20210501,gnomad_genome,dbscsnv11,rmsk,ensGene,knownGene,refGeneWithVer,gnomad_exome,spidex \
			-operation  g,f,f,f,f,f,f,f,r,g,g,g,f,f \
			--argument '-hgvs',,,,,,,,,,,'-hgvs -splicing 50',, \
			--polish -nastring . \
			--thread {threads} \
			--otherinfo
		python /data/OGL/resources/git/InterVar/Intervar.py \
			-b $ver \
			-t /data/OGL/resources/git/InterVar/intervardb \
			-c /data/OGL/resources/git/InterVar/config.ini \
			-i {output.avinput} \
			--input_type=AVinput \
			-d $ANNOVAR_DATA/$ver \
			-o {output.avinput} \
			--skip_annovar
		mv {output.avinput}.*_multianno.txt {output.annovar_out}
		mv {output.avinput}.*_multianno.txt.intervar {output.intervar_out}
		"""

# module load {config[InterVar_version]}
# InterVar \
# 	-i {output.avinput} \
# 	--input_type=AVinput \
# 	-d $ANNOVAR_DATA/hg19 \
# 	--evidence_file={input.InterVarEvidence} \
# 	-o {output.avinput} \
# 	--skip_annovar

if config['spliceai_wrapper'] == 'TRUE':
	rule spliceai_wrapper:
		input:
			vcf = 'temp/vt.{sample}__{region}.vcf.gz',
			index = 'temp/vt.{sample}__{region}.vcf.gz.tbi'
		output:
			vcf = temp('temp/spliceai.{sample}__{region}.vcf.gz'),
			index = temp('temp/spliceai.{sample}__{region}.vcf.gz.tbi')
		shell:
			"""
			module load {config[spliceai-wrapper_version]}
			module load {config[samtools_version]}
			spliceai-wrapper annotate \
				--input-vcf {input.vcf} \
				--output-vcf {output.vcf} \
				--precomputed-db-path /data/OGVFB/OGL_NGS/variant_prioritization/data/spliceai_wrapper/precomputed.sqlite3 \
				--cache-db-path /data/OGVFB/OGL_NGS/variant_prioritization/data/spliceai_wrapper/cache.sqlite3 \
				--release GRCh37 \
				--path-reference {config[ref_genome]} \
				--genes-tsv /data/OGVFB/OGL_NGS/variant_prioritization/data/spliceai_wrapper/grch37.txt
			tabix -f -p vcf {output.vcf}
			"""
else:
	rule spliceai:
		input:
			vcf = 'temp/{sample}__{region}.vcf.gz',
			index = 'temp/{sample}__{region}.vcf.gz.tbi'
		output:
			barevcf = temp('temp/{sample}__{region}.bare.vcf.gz'),
			barevcfindex = temp('temp/{sample}__{region}.bare.vcf.gz.tbi'),
			new_anno_spliceai = temp('temp/{sample}__{region}.new.spliceai.vcf.gz'),
			new_anno_spliceai_index = temp('temp/{sample}__{region}.new.spliceai.vcf.gz.tbi'),
			vcf = temp('temp/spliceai.{sample}__{region}.vcf.gz'),
			index = temp('temp/spliceai.{sample}__{region}.vcf.gz.tbi')
		threads: 8
		shell:
			"""
			module load {config[samtools_version]} && echo "samtools loaded" || exit 1
			echo -e "##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO" > /lscratch/$SLURM_JOB_ID/vcf.header && echo "vcf.header" || exit 1
			( bcftools view --no-header -Ov {input.vcf} | awk -F"\t" 'BEGIN{{OFS="\t"}} {{print $1,$2,".",$4,$5,".",".","."}}' - | cat /lscratch/$SLURM_JOB_ID/vcf.header - | bgzip --threads $(({threads}-2)) -c > {output.barevcf} ) && echo "barevcf" || exit 1
			tabix -f -p vcf {output.barevcf} && echo "index barevcf" || exit 1
			bcftools isec --threads {threads} -Oz -p /lscratch/$SLURM_JOB_ID {output.barevcf} /data/OGL/resources/spliceai/spliceai500.depot.GRCh38.vcf.gz && echo "isec" || exit 1
			module load {config[spliceai_version]}
			if [[ {config[genomeBuild]} == "GRCh38" ]]; then
				ver=grch38
			else
				ver=grch37
			fi
			spliceai -I /lscratch/$SLURM_JOB_ID/0000.vcf.gz -R {config[ref_genome]} -A $ver -D 500 -M 0 -O {output.new_anno_spliceai} && echo "spliceai" || exit 1
			tabix -f -p vcf {output.new_anno_spliceai}
			bcftools concat --threads {threads} -a {output.new_anno_spliceai} /lscratch/$SLURM_JOB_ID/0003.vcf.gz | bcftools sort -T /lscratch/$SLURM_JOB_ID/ -m 16G -Oz -o {output.vcf}
			tabix -f -p vcf {output.vcf}
			"""
# if [[ $(cat test.empty.vcf |  grep -v "^#" | wc -l) = 0 ]]; then echo "empty"; else echo "spliceai"; fi
#| head -n 500 | grep "^#" | awk -F"\t" 'BEGIN{{OFS="\t"}} /^##/ {{print $0; next;}} !/^##/ {{print $1,$2,$3,$4,$5,$6,$7,$8}}' - > /lscratch/$SLURM_JOB_ID/ this line was fine in sinteractive but threw error code in snakemake run
##spliceAI: -M 1: Mask scores representing annotated acceptor/donor gain and unannotated acceptor/donor loss (default: 0). SpliceAI authors recommend using raw files for alternative splicing analysis and masked files for variant interpretation.
## changed to -M 0 on 8/7/2020 because of pax6 variant.
localrules: spliceai_edit
rule spliceai_edit:
	input:
		'temp/spliceai.{sample}__{region}.vcf.gz'
	output:
		tsv = temp('temp/spliceai.{sample}__{region}.tsv'),
		tsv_cut = temp('temp/spliceai.{sample}__{region}.tsv.cut')
	#	index = temp('temp/spliceai.vt.{sample}__{region}.tsv.gz.tbi')
	shell:
	# use spliceai_vcfanno_v3.sh file for non-split files
		"""
	 	module load {config[samtools_version]}
		module load {config[VCF-kit_version]}
		vk vcf2tsv wide --print-header {input} > {output.tsv}
		cut -f 1-5,$(head -1 {output.tsv} | sed "s/\\t/\\n/g" | grep -n "^SpliceAI$" | cut -f 1 -d:) {output.tsv} \
		| awk -F"\t" 'BEGIN{{OFS="\t"}} !/,/ {{split($6, splices, "|"); max = splices[3]; for(m = 3; m <=6; m++) {{if(max<splices[m]) max = splices[m]}} print $0,max; next; }} /,/ {{n = split($6,annotation,","); max = 0; anno = annotation[1]; for (i = 1; i <=n; i++) {{split(annotation[i],splices,"|"); for(m = 3; m <=6; m++) {{if(max<splices[m]) {{max = splices[m]; anno = annotation[i]}}}}; }}; print $1,$2,$3,$4,$5,anno,max }}' - \
		| awk -F"\t" 'BEGIN{{OFS="\t"}} NR==1 {{$7="spliceai_maxscore"; print $0}} NR>1 {{if ($6==".") {{$7="."; print $0}} else {{print $0}} }}' - \
		| awk -F"\t" 'BEGIN{{OFS="\t"}} NR==1 {{$8="spliceai_rank"; print $0}} NR>1 {{ if ($7==".") {{$8 = 0}} else {{ if ($7 >= 0.8) {{$8 = 8}} else {{if ($7 >= 0.5) {{$8 = 6}} else {{if ($7 >= 0.2) {{$8 = 3}} else {{if ($7 >= 0.15) {{$8 = 1}} else {{$8 = 0}}}}}} }}}}; print $0}}' -  > {output.tsv_cut}
		"""
#Snakemake use {} as special wildcard, need to replace with {{}}.
#Also better use double quotation marks "" instead of ''.
#in sed, it appearst that \t needs to be \\t (or double quotations?)

# rule merge_spliceai:
# 	input:
# 		expand('temp/spliceai.{sample}__{region}.tsv.temp', sample=SAMPLE, region=REGIONS)
# 	output:
# 		'temp/spliceai.tsv.gz'
# 	shell:
# 		"""
# 		module load {config[samtools_version]}
# 		head -n 1 {input} | grep "^CHROM" | uniq > temp/spliceai_header
# 		cat {input} | grep -v "^CHROM" | sort -k1,1 -k2,2n > {output}TEMP
# 		cat temp/spliceai_header {output}TEMP | bgzip -f > {output}
# 		tabix -b 2 -e 2 -S 1 {output}
# 		"""
#localrules: squirls
rule squirls:
	input:
		vcf = 'temp/{sample}__{region}.vcf.gz',
		index = 'temp/{sample}__{region}.vcf.gz.tbi'
	output:
		barevcf = temp('temp/{sample}__{region}.bare.csv'),
		#barevcfindex = temp('temp/{sample}__{region}.bare.vcf.gz.tbi'),
		vcf = temp('temp/squirls.{sample}__{region}.csv'),
		#index = temp('temp/squirls.{sample}__{region}.vcf.gz.tbi')
	shell:
		"""
		module load {config[samtools_version]}
		#echo -e "##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO" > /lscratch/$SLURM_JOB_ID/vcf.header
		bcftools view --no-header -Ov {input.vcf} | awk -F"\t" 'BEGIN{{OFS=","}} NR==1 {{print "CHROM,POS,REF,ALT"}} NR>1 {{print $1,$2,$4,$5}}' - > {output.barevcf}
		#tabix -f -p vcf {output.barevcf}
		module load java
		java -jar /data/OGL/resources/squirls-cli-1.0.0/squirls-cli-1.0.0.jar \
			annotate-csv \
			/data/OGL/resources/squirls/squirls-config_hg38.yml \
			{output.barevcf} {output.vcf}
		#tabix -f -p vcf {output.vcf}
		"""
localrules: merge_squirls_vcf
rule merge_squirls_vcf:
	input:
		vcf = expand('temp/squirls.{{sample}}__{region}.csv', region=REGIONS),
		#index = expand('temp/squirls.{{sample}}__{region}.vcf.gz.tbi', region=REGIONS)
	output:
		vcf = '{sample}.squirls.tsv.gz',
		#index = '{sample}.squirls.tsv.gz.tbi'
	threads: 16
	shell:
		"""
		export REF_CACHE=/lscratch/$SLURM_JOB_ID/
		module load {config[samtools_version]}
		cat {input.vcf} | sed 's/,/\t/g' - | bgzip -c > {output.vcf} #be aware of the first line
		#bcftools concat --threads {threads} {input.vcf} | bcftools sort -T /lscratch/$SLURM_JOB_ID/ -m 100G -O z -o {output.vcf}
		#tabix -f -p vcf {input.vcf}
		"""

localrules: spliceai_intervar_edit
rule spliceai_intervar_edit:
	input:
		spliceai = 'temp/spliceai.{sample}__{region}.tsv.cut',
		annovar = 'temp/{sample}__{region}.avinput.multianno.txt',
		intervar = 'temp/{sample}__{region}.avinput.multianno.txt.intervar'
	output:
		intermediate = temp('temp/{sample}__{region}.avinput.multianno.modified.txt'),
		spliceai_intervar = temp('temp/{sample}__{region}.spliceai_annovar_intervar'),
		header = temp('temp/{sample}__{region}.annovar_intervar_header'),
		gz = temp('temp/{sample}__{region}.spliceai_annovar_intervar_annotation.txt.gz')
	shell:
		"""
		module load {config[R_version]}
		cut -f -128 {input.annovar} | sed "1 s/Otherinfo1\tOtherinfo2\tOtherinfo3\tOtherinfo4\tOtherinfo5\tOtherinfo6\tOtherinfo7/CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER/" - > {output.intermediate}
		Rscript {config[intervar_Rscript_path]} \
			{input.intervar} \
			{output.intermediate} \
			{input.spliceai} \
			{config[HGMDtranscript]} \
			{output.spliceai_intervar}
		module load {config[samtools_version]}
		head -n 1 {output.spliceai_intervar} > {output.header}
		tail -n +2 {output.spliceai_intervar} | sort -k1,1 -k2,2n | cat {output.header} - | bgzip -f > {output.gz}
		tabix -b 2 -e 2 -S 1 {output.gz}
		"""

#133 to 132 3/30/21
# rule merge_annovar_intervar:
# 	input:
# 		expand('temp/{sample}__{region}.spliceai_annovar_intervar', sample=SAMPLE, region=REGIONS)
# 	output:
# 		'temp/spliceai_annovar_intervar_annotation.txt.gz'
# 	shell:
# 		"""
# 		module load {config[samtools_version]}
# 		head -n 1 {input} | grep "^CHROM" | uniq > temp/annovar_intervar_header
# 		cat {input} | grep -v "^CHROM" | sort -k1,1 -k2,2n > {output}TEMP
# 		cat temp/annovar_intervar_header {output}TEMP | bgzip -f > {output}
# 		tabix -b 2 -e 2 -S 1 {output}
# 		"""

# in above sort, will it work with alternative alleles?

# annotate with VEP
# two paths here, set by config['pick'] in config.yaml and the pick() function:
# 1. 'canonical' only returns one consequence per variant.
# 		Use this for clinical returns, as no risk of using odd tx with
# 		high consequence as choice in gemini
# 2. 'all' will do multiple annotations with VEP and gemini will use
# 	the most serious consequence.
# 		Use for more research returns, to increase chances of finding
# 		interesting variants at cost of lower specificity.

#localrules: VEP_annotate
rule VEP_annotate:
	input:
		vcf = 'temp/{sample}__{region}.vcf.gz',
		index = 'temp/{sample}__{region}.vcf.gz.tbi'
	output:
		vcf = temp('temp/{sample}__{region}.SORTED.VT.VEP.vcf.gz'),
		index = temp('temp/{sample}__{region}.SORTED.VT.VEP.vcf.gz.tbi')
	threads: 4
	params:
		pick = pick()
	shell:
		"""
		module load {config[VEP_version]}
		module load {config[samtools_version]}
		if [[ {config[genomeBuild]} == "GRCh38" ]]; then
			CADD_PLUGIN="--plugin CADD,$VEPCACHEDIR/CADD_1.6_GRCh38_whole_genome_SNVs.tsv.gz,$VEPCACHEDIR/CADD_1.6_GRCh38_gnomad.genomes.r3.0.indel.tsv.gz"
			SPLICEAI_PLUGIN="--plugin SpliceAI,snv=$VEPCACHEDIR/spliceai_scores.masked.snv.hg38.vcf.gz,indel=$VEPCACHEDIR/spliceai_scores.masked.indel.hg38.vcf.gz"
		else
			CADD_PLUGIN="--plugin CADD,$VEPCACHEDIR/CADD_1.6_GRCh37_whole_genome_SNVs.tsv.gz,$VEPCACHEDIR/CADD_1.6_GRCh37_InDels.tsv.gz "
			SPLICEAI_PLUGIN="--plugin SpliceAI,snv=$VEPCACHEDIR/spliceai_scores.masked.snv.hg19.vcf.gz,indel=$VEPCACHEDIR/spliceai_scores.masked.indel.hg19.vcf.gz"
		fi
		vep -i {input.vcf} --offline --fork 4 \
			--cache --dir_cache $VEPCACHEDIR \
			--fasta $VEPCACHEDIR/{config[genomeBuild]}.fa --species human --assembly {config[genomeBuild]}  \
			--format vcf \
			--output_file {output.vcf} \
			--plugin GeneSplicer,$GS/bin/genesplicer,$GS/human,context=200 \
            --plugin SpliceRegion \
			--plugin MaxEntScan,/data/OGL/resources/variant_annotation/data/MaxEntScan \
			$CADD_PLUGIN \
			--plugin MPC,/data/OGL/resources/variant_annotation/data/MPC/fordist_constraint_official_mpc_values_v2.txt.gz \
			--plugin UTRannotator,$VEPCACHEDIR/uORF_5UTR_{config[genomeBuild]}_PUBLIC.txt \
			--ccds \
			--total_length \
			--hgvs \
			--shift_hgvs 1 \
			--sift b \
			--polyphen b \
			--symbol \
			--check_existing \
			--numbers \
			--biotype \
			--total_length \
			--pubmed \
			--domains \
			--gene_phenotype \
			--max_af \
			{params.pick} \
            --fields Allele,Consequence,Codons,Amino_acids,Gene,SYMBOL,Feature,EXON,HGVSc,HGVSp,MAX_AF,MAX_AF_POPS,PolyPhen,SIFT,MPC,Protein_position,BIOTYPE,CANONICAL,DOMAINS,Existing_variation,CLIN_SIG,PICK,PUBMED,Phenotypes,CADD_RAW,CADD_PHRED,GeneSplicer,SpliceRegion,MaxEntScan_diff,existing_InFrame_oORFs,existing_OutOfFrame_oORFs,existing_uORFs,five_prime_UTR_variant_annotation,five_prime_UTR_variant_consequence \
			--vcf --compress_output bgzip --force_overwrite
		# tabix
		tabix -f -p vcf {output.vcf}
		"""
# to be added: https://www.ebi.ac.uk/gene2phenotype/g2p_vep_plugin
#--mane, output MANE_SELECT, MANE_PLUS_CLINICAL
#remove Grantham. 5/21/2020: remove --canonical
#remove --plugin dbscSNV,$VEPCACHEDIR/dbscSNV1.1.txt.gz & ada_score,rf_score, from fields \ because included in annovar and didn't try to find the GRCh38 files
#SpliceAI plugin was not added because vcf output had fields separated. Used vcfanno instead.


localrules: vcfanno_annotate
rule vcfanno_annotate:
	input:
		annovar_intervar = 'temp/{sample}__{region}.spliceai_annovar_intervar_annotation.txt.gz',
		vcf = 'temp/{sample}__{region}.SORTED.VT.VEP.vcf.gz',
		index = 'temp/{sample}__{region}.SORTED.VT.VEP.vcf.gz.tbi'
	output:
		new_conf = temp('temp/{sample}__{region}_vcfanno.conf'),
		vcf = temp('temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.vcf.gz'),
		index = temp('temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi')
	threads: 4
	shell:
		"""
		module load {config[samtools_version]}
		module load {config[vcfanno_version]}
		# copy conf to local dir, then edit to put in the path
		# to the annovar_intervar this Snakemake creates
		cp {config[vcfanno_conf]} {output.new_conf}
		annovar_intervar_path=`echo {input.annovar_intervar} | sed 's:/:\\\\\/:g'`
		sed -i "s/ANNOVAR_INTERVAR_FILE/$annovar_intervar_path/g" {output.new_conf}
		vcfanno -p {threads} -lua {config[vcfanno_lua]} {output.new_conf} {input.vcf} | sed 's/Number=A/Number=1/g' | bgzip > {output.vcf}
		tabix -f -p vcf {output.vcf}
		"""

# localrules: priority_scores
# rule priority_scores:
# 	input:
# 		vcf = 'temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.vcf.gz',
# 		index = 'temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
# 	output:
# 		tsv = temp('temp/{sample}__{region}.tsv'),
# 		ps_tsv = temp('temp/{sample}__{region}.ps.tsv'),
# 		bgzip = temp('temp/{sample}__{region}.ps.tsv.gz'),
# 		index = temp('temp/{sample}__{region}.ps.tsv.gz.tbi')
# 	shell:
# 		"""
# 		module load {config[vt_version]}
# 		module load {config[R_version]}
# 		module load {config[samtools_version]}
# 		vt info2tab -t CSQ,Ref_Gene,ExonicFunc_refGeneWithVer,gnomAD_exome_ALL_annovar,gnomAD_genome_ALL_annovar,PopFreqMax_annovar,gno_af_popmax,mis_z,clinvar_sig,Clinvar_intervar,HGMD_Overlap,ClinPred_Score,MetaSVM_pred,revel,MutationAssessor_pred,MutationTaster_pred,PROVEAN_pred,Eigen-PC-raw,Eigen-raw,phyloP_100way,GERP_RS_intervar,dpsi_max_tissue_annovar,dpsi_zscore_annovar,dbscSNV_ADA_SCORE_intervar,dbscSNV_RF_SCORE_intervar,spliceai_rank,Priority_Score_intervar,PVS1,SigmaAF_Missense_0001,PrimateDL,ccr_pct,remm,fathmm_xf_coding,fathmm_xf_noncoding,atac_rpe_itemRgb,ft_ret_rpe_score {input.vcf} \
# 		 	| sed '1 s/^.*$/CHROM\tPOS\tREF\tALT\tN_ALLELE\tCSQ\tRef_Gene\tExonicFunc_refGeneWithVer\tgnomAD_exome_ALL_annovar\tgnomAD_genome_ALL_annovar\tPopFreqMax_annovar\tgno_af_popmax\tmis_z\tclinvar_sig\tClinvar_intervar\tHGMD_Overlap\tClinPred_Score\tMetaSVM_pred\trevel\tMutationAssessor_pred\tMutationTaster_pred\tPROVEAN_pred\tEigen_PC_raw\tEigen_raw\tphyloP_100way\tGERP_RS_intervar\tdpsi_max_tissue_annovar\tdpsi_zscore_annovar\tdbscSNV_ADA_SCORE_intervar\tdbscSNV_RF_SCORE_intervar\tspliceai_rank\tPriority_Score_intervar\tPVS1\tSigmaAF_Missense_0001\tPrimateDL\tccr_pct\tremm\tfathmm_xf_coding\tfathmm_xf_noncoding\tatac_rpe_itemRgb\tft_ret_rpe_score/' - \
# 			> {output.tsv}
# 		Rscript /home/$USER/git/variant_prioritization/src/priority_score.R {output.tsv} {output.ps_tsv}
# 		bgzip -c {output.ps_tsv} > {output.bgzip}
# 		tabix -b 2 -e 2 -S 1 {output.bgzip}
# 		"""
#
# # annotate with vcfanno
# localrules: vcfanno2
# rule vcfanno2:
# 	input:
# 		priority_score = 'temp/{sample}__{region}.ps.tsv.gz',
# 		ps_index = 'temp/{sample}__{region}.ps.tsv.gz.tbi',
# 		vcf = 'temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.vcf.gz',
# 	 	index = 'temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
# 	output:
# 		new_conf = temp('temp/{sample}__{region}_vcfanno2.conf'),
# 		vcf = temp('temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz'),
# 		index = temp('temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz.tbi')
# 	threads: 4
# 	shell:
# 		"""
# 		module load {config[samtools_version]}
# 		module load {config[vcfanno_version]}
# 		cp /home/$USER/git/variant_prioritization/src/vcfanno2.conf {output.new_conf}
# 		priority_score_path=`echo {input.priority_score} | sed 's:/:\\\\\/:g'`
# 		sed -i "s/priority_score_file/$priority_score_path/g" {output.new_conf}
# 		vcfanno -p {threads} {output.new_conf} {input.vcf} | bgzip > {output.vcf}
# 		tabix -f -p vcf {output.vcf}
# 		"""


# fix number=A issue
# Since I decompose variants into multiple lines,
# I can make number=1 so vcf2b will keep
# localrules: tweak_header
# rule tweak_header:
# 	input:
# 		'temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO2.vcf.gz'
# 	output:
# 		vcf = temp('temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz'),
# 		index = temp('temp/{sample}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz.tbi')
# 	shell:
# 		"""
# 		#module load {config[samtools_version]}
# 		#zcat {input} | sed 's/Number=A/Number=1/g' | bgzip -c > {output.vcf}
# 		cp {input} {output.vcf}
# 		tabix -f -p vcf {output.vcf}
# 		"""


# merge vcfs into one again
if config['spliceai_wrapper'] == 'TRUE':
	rule merge_sample_vcf:
		input:
			vcf = expand('temp/{{sample}}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz', region=REGIONS),
			index = expand('temp/{{sample}}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz.tbi', region=REGIONS)
		output:
			vcf = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz',
			index = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
		threads: 16
		shell:
			"""
			export REF_CACHE=/lscratch/$SLURM_JOB_ID/
			module load {config[samtools_version]}
			bcftools concat --threads {threads} {input.vcf} -O z -o {output.vcf}
			tabix -f -p vcf {output.vcf}
			"""
else:
	rule merge_sample_vcf:
		input:
			vcf = expand('temp/{{sample}}__{region}.SORTED.VT.VEP.VCFANNO.vcf.gz', region=REGIONS),
			index = expand('temp/{{sample}}__{region}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi', region=REGIONS)
		output:
			vcf = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz',
			index = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
		threads: 16
		shell:
			"""
			export REF_CACHE=/lscratch/$SLURM_JOB_ID/
			module load {config[samtools_version]}
			bcftools concat --threads {threads} {input.vcf} | bcftools sort -T /lscratch/$SLURM_JOB_ID/ -m 100G -O z -o {output.vcf}
			tabix -f -p vcf {output.vcf}
			"""
	rule merge_spliceai_vcf:
		input:
			vcf = expand('temp/{{sample}}__{region}.new.spliceai.vcf.gz', region=REGIONS),
			index = expand('temp/{{sample}}__{region}.new.spliceai.vcf.gz.tbi', region=REGIONS)
		output:
			temp('temp/{sample}.spliceai.new.vcf.depot.merged')
		threads: 16
		shell:
			"""
			export REF_CACHE=/lscratch/$SLURM_JOB_ID/
			module load {config[samtools_version]}
			bcftools concat --threads {threads} {input.vcf} -Oz -o /lscratch/$SLURM_JOB_ID/new.spliceai.vcf.gz
			tabix -f -p vcf /lscratch/$SLURM_JOB_ID/new.spliceai.vcf.gz
			( bcftools concat --threads {threads} -a --rm-dups none --no-version \
				/data/OGL/resources/spliceai/spliceai500.depot.GRCh38.vcf.gz /lscratch/$SLURM_JOB_ID/new.spliceai.vcf.gz \
				-Oz -o /lscratch/$SLURM_JOB_ID/spliceai500.depot.GRCh38.vcf.gz ) || exit 1
			tabix -f -p vcf /lscratch/$SLURM_JOB_ID/spliceai500.depot.GRCh38.vcf.gz || exit 1
			cp /lscratch/$SLURM_JOB_ID/spliceai500.depot.GRCh38.vcf.gz* /data/OGL/resources/spliceai
			touch {output}
			"""

#below with sorting which is time-consuming. Tested no sort on 1/30/21
# if config['spliceai_wrapper'] == 'TRUE':
# 	rule merge_vcf:
# 		input:
# 			vcf = expand('temp/{{sample}}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz', region=REGIONS),
# 			index = expand('temp/{{sample}}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz.tbi', region=REGIONS)
# 		output:
# 			vcf = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz',
# 			index = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
# 		threads: 16
# 		shell:
# 			"""
# 			export REF_CACHE=/lscratch/$SLURM_JOB_ID/
# 			module load {config[samtools_version]}
# 			bcftools concat --threads {threads} {input.vcf} | bcftools sort -T /lscratch/$SLURM_JOB_ID/ -m 100G -O z -o {output.vcf}
# 			tabix -f -p vcf {output.vcf}
# 			"""
# else:
# 	rule merge_vcf:
# 		input:
# 			vcf = expand('temp/{{sample}}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz', region=REGIONS),
# 			index = expand('temp/{{sample}}__{region}.SORTED.VT.VEP.VCFANNO.NUMFIX.vcf.gz.tbi', region=REGIONS),
# 			spliceai_vcf = expand('temp/{{sample}}__{region}.new.spliceai.vcf.gz', region=REGIONS),
# 			spliceai_index = expand('temp/{{sample}}__{region}.new.spliceai.vcf.gz.tbi', region=REGIONS)
# 		output:
# 			vcf = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz',
# 			index = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
# 		threads: 16
# 		shell:
# 			"""
# 			export REF_CACHE=/lscratch/$SLURM_JOB_ID/
# 			module load {config[samtools_version]}
# 			bcftools concat --threads {threads} {input.vcf} | bcftools sort -T /lscratch/$SLURM_JOB_ID/ -m 100G -O z -o {output.vcf}
# 			tabix -f -p vcf {output.vcf}
# 			( bcftools concat --threads {threads} -a --rm-dups none --no-version \
# 				/data/OGL/resources/spliceai/spliceai500.depot.vcf.gz {input.spliceai_vcf} \
# 				| bcftools sort -T /lscratch/$SLURM_JOB_ID/ -m 100G -Oz -o /lscratch/$SLURM_JOB_ID/spliceai500.depot.vcf.gz ) || exit 1
# 			tabix -f -p vcf /lscratch/$SLURM_JOB_ID/spliceai500.depot.vcf.gz || exit 1
# 			cp /lscratch/$SLURM_JOB_ID/spliceai500.depot.vcf.gz* /data/OGL/resources/spliceai
# 			"""

#spliceai file merge step took ~ 1hour for the 4gb first 500 files.
#if config['re_sort'] == 'TRUE':
	# ensure that the concat didn't mess up the order
#	rule sort_tabix:
#		input:
#			vcf = 'temp/{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz'
#		output:
#			vcf = protected('{sample}.RESORTED.VT.VEP.VCFANNO.vcf.gz'),
#			index = '{sample}.RESORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
#		shell:
#			"""
#			export REF_CACHE=/scratch/$SLURM_JOB_ID/
#			/home/mcgaugheyd/bin/gsort_linux_amd64 --memory 60000 {input.vcf} /data/mcgaugheyd/genomes/1000G_phase2_GRCh37/GRCh37_gatk_order.genome | bgzip -c > {output.vcf}
#			tabix -f -p vcf {output.vcf}
#			"""
#else:
#	rule faux_sort_tabix:
#		input:
#			vcf = 'temp/{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz',
#			index = 'temp/{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
#		output:
#			vcf = protected('{sample}.RESORTED.VT.VEP.VCFANNO.vcf.gz'),
#			index = '{sample}.RESORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
#		shell:
#			"""
#			module load {config[samtools_version]}
#			mv {input.vcf} {output.vcf}
#			mv {input.index} {output.vcf}
#			"""

rule peddy_QC:
	input:
		'{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz'
	output:
		ped = '{sample}_PEDDY.ped_check.csv',
		het = '{sample}_PEDDY.het_check.csv',
		sex = '{sample}_PEDDY.sex_check.csv'
	threads: 4
	shell:
		"""
		module load {config[peddy_version]}
		peddy -p {threads} {input} {config[ped]} --prefix {wildcards.sample}_PEDDY
		"""


# create gemini database. 19gb wgs genome --> 104gb in 24 hours.
localrules: make_gemini_db
rule make_gemini_db:
	input:
		vcf = '{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz',
#		index = 'temp/{sample}.SORTED.VT.VEP.VCFANNO.vcf.gz.tbi'
	output:
		'{sample}.PED_{ped}.gemini.db'
#	threads: 8
	shell:
		"""
		module unload python
		module load {config[vcf2db_version]}
		echo {wildcards.ped}.ped
		vcf2db.py {input.vcf} {PEDbase}{wildcards.ped}.ped {output}
		"""


#
#		module load {config[gemini_version]}
#		gemini load -v {input.vcf} -t VEP -p {config[ped]} --skip-gerp-bp --skip-cadd --cores {threads} {output}
#		--skip-gene-tables --save-info-string needed? the size generated using load is 4x larger than vcf2db.py below, but the db file cannot be queried as before, probably only VEP fields are included.
# 8/4/19:  --info-exclude MLEAF --info-exclude MLEAC because EU's exome data has 2 values in these two fields.
#took 12 hours for a genome 4/12/21
if config['datatype'].upper() in ["WGS", "GENOME"]:
	rule query_gemini_family:
		input:
			db = '{sample}.PED_{ped}.gemini.db'
		output:
			xlsx = 'gemini_xlsx/{family_name}.{sample}.{ped}.lenient{gemini_lenient}.xlsx'
		shell:
			"""
			module load {config[gemini_version]} {config[R_version]}
			cp {input} /lscratch/$SLURM_JOB_ID/.
			mkdir -p /lscratch/$SLURM_JOB_ID/{wildcards.family_name}
			WKDIR=/lscratch/$SLURM_JOB_ID/{wildcards.family_name}
			LENIENT={config[gemini_lenient]}
			case "${{LENIENT^^}}" in
				"YES"|"TRUE")
					time gemini de_novo -d 9 --min-gq 5 --lenient --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/denovo.tsv
					time gemini autosomal_dominant -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/ad.tsv
					time gemini autosomal_recessive -d 9 --min-gq 5 --lenient --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/ar.tsv
					time gemini comp_hets -d 9 --min-gq 5 --gene-where "priority_score >= 5" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/comphets.tsv
					time gemini x_linked_de_novo -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xdenovo.tsv
					time gemini x_linked_dominant -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xd.tsv
					time gemini x_linked_recessive -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xr.tsv
					time gemini mendel_errors -d 9 --min-gq 5 --lenient --filter "priority_score > 3" --only-affected --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/mendel_errors.tsv
					;;
				*)
					time gemini de_novo -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/denovo.tsv
					time gemini autosomal_dominant -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/ad.tsv
					time gemini autosomal_recessive -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/ar.tsv
					time gemini comp_hets -d 9 --min-gq 5 --gene-where "priority_score >= 5" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/comphets.tsv
					time gemini x_linked_de_novo -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xdenovo.tsv
					time gemini x_linked_dominant -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xd.tsv
					time gemini x_linked_recessive -d 9 --min-gq 5 --filter "priority_score > 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xr.tsv
					time gemini mendel_errors -d 9 --min-gq 5 --filter "priority_score > 3" --only-affected --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/mendel_errors.tsv
					;;
			esac
			Rscript /home/$USER/git/variant_prioritization/src/sortGeminiFamily.R \
				{config[OGL_Dx_research_genes]} {config[aaf_change]} {output.xlsx} {wildcards.family_name} \
				$WKDIR/denovo.tsv $WKDIR/ad.tsv $WKDIR/ar.tsv $WKDIR/comphets.tsv $WKDIR/xdenovo.tsv $WKDIR/xd.tsv $WKDIR/xr.tsv $WKDIR/mendel_errors.tsv
			"""
elif config['datatype'].upper() in ["EXOME", "WES"]:
		rule query_gemini_family:
			input:
				db = '{sample}.PED_{ped}.gemini.db'
			output:
				xlsx = 'gemini_xlsx/{family_name}.{sample}.{ped}.lenient{gemini_lenient}.xlsx'
			shell:
				"""
				module load {config[gemini_version]} {config[R_version]}
				cp {input} /lscratch/$SLURM_JOB_ID/.
				mkdir -p /lscratch/$SLURM_JOB_ID/{wildcards.family_name}
				WKDIR=/lscratch/$SLURM_JOB_ID/{wildcards.family_name}
				LENIENT={config[gemini_lenient]}
				case "${{LENIENT^^}}" in
					"YES"|"TRUE")
						time gemini de_novo -d 9 --min-gq 5 --lenient --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/denovo.tsv
						time gemini autosomal_dominant -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/ad.tsv
						time gemini autosomal_recessive -d 9 --min-gq 5 --lenient --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/ar.tsv
						time gemini comp_hets -d 9 --min-gq 5 --gene-where "priority_score >= 4" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/comphets.tsv
						time gemini x_linked_de_novo -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xdenovo.tsv
						time gemini x_linked_dominant -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xd.tsv
						time gemini x_linked_recessive -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xr.tsv
						time gemini mendel_errors -d 9 --min-gq 5 --lenient --filter "priority_score >= 3" --only-affected --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/mendel_errors.tsv
						;;
					*)
						time gemini de_novo -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/denovo.tsv
						time gemini autosomal_dominant -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/ad.tsv
						time gemini autosomal_recessive -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/ar.tsv
						time gemini comp_hets -d 9 --min-gq 5 --gene-where "priority_score >= 4" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/comphets.tsv
						time gemini x_linked_de_novo -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xdenovo.tsv
						time gemini x_linked_dominant -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xd.tsv
						time gemini x_linked_recessive -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/xr.tsv
						time gemini mendel_errors -d 9 --min-gq 5 --filter "priority_score >= 3" --only-affected --families {wildcards.family_name} /lscratch/$SLURM_JOB_ID/{input} > $WKDIR/mendel_errors.tsv
						;;
				esac
				Rscript /home/$USER/git/variant_prioritization/src/sortGeminiFamily.R \
					{config[OGL_Dx_research_genes]} {config[aaf_change]} {output.xlsx} {wildcards.family_name} \
					$WKDIR/denovo.tsv $WKDIR/ad.tsv $WKDIR/ar.tsv $WKDIR/comphets.tsv $WKDIR/xdenovo.tsv $WKDIR/xd.tsv $WKDIR/xr.tsv $WKDIR/mendel_errors.tsv
				"""
else:
	localrules: query_gemini_family
	rule query_gemini_family:
		input:
			db = '{sample}.PED_{ped}.gemini.db'
		output:
			xlsx = 'gemini_xlsx/{family_name}.{sample}.{ped}.lenient{gemini_lenient}.xlsx'
		resources: res=1
		shell:
			"""
			module load {config[gemini_version]} {config[R_version]}
			mkdir -p /lscratch/$SLURM_JOB_ID/{wildcards.family_name}
			WKDIR=/lscratch/$SLURM_JOB_ID/{wildcards.family_name}
			LENIENT={config[gemini_lenient]}
			case "${{LENIENT^^}}" in
				"YES"|"TRUE")
					time gemini de_novo -d 9 --min-gq 5 --lenient --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/denovo.tsv
					time gemini autosomal_dominant -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/ad.tsv
					time gemini autosomal_recessive -d 9 --min-gq 5 --lenient --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/ar.tsv
					time gemini comp_hets -d 9 --min-gq 5 --gene-where "priority_score >= 4" --families {wildcards.family_name} {input} > $WKDIR/comphets.tsv
					time gemini x_linked_de_novo -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/xdenovo.tsv
					time gemini x_linked_dominant -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/xd.tsv
					time gemini x_linked_recessive -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/xr.tsv
					time gemini mendel_errors -d 9 --min-gq 5 --lenient --filter "priority_score >= 3" --only-affected --families {wildcards.family_name} {input} > $WKDIR/mendel_errors.tsv
					;;
				*)
					time gemini de_novo -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/denovo.tsv
					time gemini autosomal_dominant -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/ad.tsv
					time gemini autosomal_recessive -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/ar.tsv
					time gemini comp_hets -d 9 --min-gq 5 --gene-where "priority_score >= 4" --families {wildcards.family_name} {input} > $WKDIR/comphets.tsv
					time gemini x_linked_de_novo -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/xdenovo.tsv
					time gemini x_linked_dominant -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/xd.tsv
					time gemini x_linked_recessive -d 9 --min-gq 5 --filter "priority_score >= 3" --families {wildcards.family_name} {input} > $WKDIR/xr.tsv
					time gemini mendel_errors -d 9 --min-gq 5 --filter "priority_score >= 3" --only-affected --families {wildcards.family_name} {input} > $WKDIR/mendel_errors.tsv
					;;
			esac
			Rscript /home/$USER/git/variant_prioritization/src/sortGeminiFamily.R \
				{config[OGL_Dx_research_genes]} {config[aaf_change]} {output.xlsx} {wildcards.family_name} \
				$WKDIR/denovo.tsv $WKDIR/ad.tsv $WKDIR/ar.tsv $WKDIR/comphets.tsv $WKDIR/xdenovo.tsv $WKDIR/xd.tsv $WKDIR/xr.tsv $WKDIR/mendel_errors.tsv
			"""

if config['datatype'].upper() in ["WGS", "GENOME", "EXOME", "WES"]:
	rule query_gemini_individual:
		input:
			db = '{sample}.PED_{ped}.gemini.db'
		output:
			tsv = 'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.tsv'
		shell:
			"""
			module load {config[gemini_version]}
			cp {input.db} /lscratch/$SLURM_JOB_ID/.
 			time gemini query -q \
			"SELECT *, gt_types.{wildcards.sampleid}, gts.{wildcards.sampleid}, gt_phases.{wildcards.sampleid}, gt_depths.{wildcards.sampleid}, gt_alt_freqs.{wildcards.sampleid}, gt_quals.{wildcards.sampleid} FROM variants WHERE priority_score > -2" \
			--header --gt-filter "gt_types.{wildcards.sampleid} != HOM_REF AND gts.{wildcards.sampleid} != './.' " /lscratch/$SLURM_JOB_ID/{input.db} > {output.tsv}
			"""
else:
	localrules: query_gemini_individual
	rule query_gemini_individual:
		input:
			db = '{sample}.PED_{ped}.gemini.db'
		output:
			tsv = 'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.tsv'
		resources: res=1
		shell:
			"""
			module load {config[gemini_version]}
 			time gemini query -q \
			"SELECT *, gt_types.{wildcards.sampleid}, gts.{wildcards.sampleid}, gt_phases.{wildcards.sampleid}, gt_depths.{wildcards.sampleid}, gt_alt_freqs.{wildcards.sampleid}, gt_quals.{wildcards.sampleid} FROM variants" \
			--header --gt-filter "gt_types.{wildcards.sampleid} != HOM_REF AND gts.{wildcards.sampleid} != './.' " {input.db} > {output.tsv}
			"""

if config['datatype'].upper() == "PANEL":
	localrules: sortGemini
	rule sortGemini:
		input:
			tsv = 'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.tsv'
		output:
			rearranged_tsv = 'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.rearranged.tsv',
			filtered_tsv = 'gemini_tsv_filtered/{sampleid}.{sample}.{ped}.gemini.filtered.tsv',
			filtered_xlsx = 'gemini_xlsx/{sampleid}.{sample}.{ped}.gemini.filtered.xlsx'
		shell:
			"""
			module load {config[R_version]}
			Rscript /home/$USER/git/variant_prioritization/src/sortGeminiTSV_v1.R \
				{input.tsv} {config[OGL_Dx_research_genes]} {output.rearranged_tsv} {output.filtered_tsv} {wildcards.sampleid} {output.filtered_xlsx} {config[aaf_change]} ../manta/manta.{wildcards.sampleid}.annotated.tsv ../scramble_anno/{wildcards.sampleid}.scramble.xlsx ../scramble_anno/{wildcards.sampleid}.scramble.del.tsv ../CoNVaDING/CNV_hiSens/{wildcards.sampleid}.markDup.aligned.only.best.score.shortlist.txt gemini_xlsx/{wildcards.sampleid}.geneLAF.pdf
	 		"""
elif config['datatype'].upper() in ["EXOME", "WES"]:
	rule sortGemini:
		input:
			tsv = 'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.tsv'
		output:
			rearranged_tsv = 'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.rearranged.tsv',
			filtered_tsv = 'gemini_tsv_filtered/{sampleid}.{sample}.{ped}.gemini.filtered.tsv',
			filtered_xlsx = 'gemini_xlsx/{sampleid}.{sample}.{ped}.gemini.filtered.xlsx'
		shell:
			"""
			module load {config[R_version]}
			Rscript /home/$USER/git/variant_prioritization/src/sortGeminiTSV_v1.R \
				{input.tsv} {config[OGL_Dx_research_genes]} {output.rearranged_tsv} {output.filtered_tsv} {wildcards.sampleid} {output.filtered_xlsx} {config[aaf_change]} ../manta/manta.{wildcards.sampleid}.annotated.tsv ../scramble_anno/{wildcards.sampleid}.scramble.xlsx ../scramble_anno/{wildcards.sampleid}.scramble.del.tsv
	 		"""
else:
	rule sortGemini:
		input:
			tsv = 'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.tsv'
		output:
			rearranged_tsv = 'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.rearranged.tsv',
			filtered_tsv = 'gemini_tsv_filtered/{sampleid}.{sample}.{ped}.gemini.filtered.tsv',
			filtered_xlsx = 'gemini_xlsx/{sampleid}.{sample}.{ped}.gemini.filtered.xlsx'
		shell:
			"""
			mkdir -p gemini_tsv_filtered gemini_xlsx
			module load {config[R_version]}
			Rscript /home/$USER/git/variant_prioritization/src/sortGeminiTSV_v1.R \
				{input.tsv} {config[OGL_Dx_research_genes]} {output.rearranged_tsv} {output.filtered_tsv} {wildcards.sampleid} {output.filtered_xlsx} {config[aaf_change]} ../manta/manta.{wildcards.sampleid}.annotated.tsv ../scramble_anno/{wildcards.sampleid}.scramble.xlsx
			"""


localrules: LesserAlleleFreq
rule LesserAlleleFreq:
	input:
		'gemini_tsv/{sampleid}.{sample}.{ped}.gemini.rearranged.tsv'
	output:
		LAFplot = 'LesserAlleleFreq/{sampleid}.{sample}.{ped}.LAF.jpeg'
	shell:
		"""
		module load {config[R_version]}
		Rscript /home/$USER/git/variant_prioritization/src/LesserAlleleFreq_singleSample.R \
			{input} {wildcards.sampleid} {output.LAFplot}
		"""

#Make a shiny app
##sbatch needs 32g for wgs or exome


localrules: query_gemini
rule query_gemini:
	input:
		db = '{sample}.PED_{ped}.gemini.db',
		peddy_ped = '{sample}_PEDDY.ped_check.csv',
		peddy_het = '{sample}_PEDDY.het_check.csv',
		peddy_sex = '{sample}_PEDDY.sex_check.csv'
	output:
		report_name = '{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report.html',
		tsv =  '{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report.tsv',
		folder = directory('{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report_files'),
#		report_path = 'sample_reports/{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report.html'
	resources: res=1
	run:
		report_name = output.report_name
	#	report_path = output.report_path
		if config["output_raw"].upper() == 'NO':
			shell("mkdir -p sample_reports; \
					module load R/3.5.2; \
					module load {config[gemini_version]}; \
					module load {config[pandoc_version]}; \
					Rscript {config[SeeGEM_script]} \
						{input.db} \
						{wildcards.family_name} \
						{output.report_name} \
						{wildcards.sample}_PEDDY \
						{config[aaf_change]} \
						{config[gemini_lenient]}")
#			shell("mv " + report_name + ' ' + report_path)
		else:
			raw_name = report_name.replace('.html','.tsv')
			#raw_path = report_path.replace('.html','.tsv')
			shell("mkdir -p sample_reports; \
					module load R/3.5.2; \
					module load {config[gemini_version]}; \
					module load {config[pandoc_version]}; \
					Rscript {config[SeeGEM_script]} \
						{input.db} \
						{wildcards.family_name} \
						{output.report_name} \
						{wildcards.sample}_PEDDY \
						{config[aaf_change]} \
						{config[gemini_lenient]} " + raw_name)
#			shell("mv " + report_name + ' ' + report_path)
#			shell("mv " + raw_name + ' ' + raw_path)

localrules: move_reports
rule move_reports:
	input:
		html = '{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report.html',
		tsv =  '{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report.tsv',
		folder = '{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report_files'
	output:
		html = 'sample_reports/{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report.html',
		tsv =  'sample_reports/{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report.tsv',
		folder = directory('sample_reports/{sample}.{family_name}.PED_{ped}.lenient{gemini_lenient}.SeeGEM.report_files')
	shell:
		"""
		mv {input.html} {output.html}
		mv {input.tsv} {output.tsv}
		mv {input.folder} {output.folder}
		"""
