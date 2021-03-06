
rule deseqSampleInfoTable:
  output:
    table = "%s/sample_info.tsv"% __DIFF_OUTDIR__
  run:
    samples = sorted(list(dconfig["samples"].keys()), key=lambda x: (dconfig["samples"][x]["replicate_group"], x))
    with open(output.table, "w") as ofd:
      ofd.write("sample\tcondition\n")
      for sample in samples:
        ofd.write("%s\t%s\n" % (sample, dconfig["samples"][sample]["replicate_group"]))
      #efor
    #ewith

rule deseqTest:
  input:
    quant       = rules.quantifyTargets.output.quant,
    sample_info = rules.deseqSampleInfoTable.output.table
  output:
    diff = "%s/test.{test}.output.tsv" %__DIFF_OUTDIR__
  conda : "%s/pipeline_components/env.yaml"% __INSTALL_DIR__
  params:
    sample1 = lambda wildcards: wildcards.test.split('-')[0],
    sample2 = lambda wildcards: wildcards.test.split('-')[1],
    deseq_wrapper = "%s/deseq_wrapper.R" % __PC_DIR__
  shell: """
    Rscript {params.deseq_wrapper} '{input.quant}' {input.sample_info} {params.sample1} {params.sample2} {output.diff}
  """

rule deseqTests:
  input:
    tests = expand("%s/test.{test}.output.tsv" % __DIFF_OUTDIR__, test=[ "%s-%s" % (a,b) for (a,b) in dconfig["tests"] ])
  output:
    tests = "%s/tests.tsv"% __DIFF_OUTDIR__
  params:
    deseq_adjust = "%s/deseq_adjust.R" % __PC_DIR__
  conda : "%s/pipeline_components/env.yaml"% __INSTALL_DIR__
  shell: """
    echo -e '"target"\t"baseMean"\t"log2FoldChange"\t"lfcSE"\t"stat"\t"pvalue"\t"padj"\t"condition"' > {output.tests}.combined
    cat {input.tests} \
     | grep -v '^"baseMean"' \
     >> {output.tests}.combined
    Rscript {params.deseq_adjust} {output.tests}.combined {output.tests}
  """

rule scriptNorm:
  input:
    quant       = rules.quantifyTargets.output.quant,
    sample_info = rules.deseqSampleInfoTable.output.table,
    frag_length  = rules.fragLengthMeans.output.fragLengthMeans
  output:
    norm = "%s/quantification.script.normalized.tsv" % __DIFF_OUTDIR__
  params:
    script_loc         = "%s/normalize_script.py" % __PC_DIR__,
    norm_type_param    = dconfig["norm_method"],
    feature_type_param = dconfig["htseq_t"],
    attr_group_param   = dconfig["htseq_i"],
    gff_file           = dconfig["genes"]
  conda: "%s/pipeline_components/env.yaml"% __INSTALL_DIR__
  shell: """
    {params.script_loc} "{params.gff_file}" "{input.quant}" "{input.sample_info}" "{input.frag_length}" "{params.attr_group_param}" "{params.feature_type_param}" "{params.norm_type_param}" "{output.norm}" 
  """

rule deseqNorm:
  input:
    quant       = rules.quantifyTargets.output.quant,
    sample_info = rules.deseqSampleInfoTable.output.table
  output:
    norm = "%s/quantification.deseq.normalized.tsv" %__DIFF_OUTDIR__
  conda : "%s/pipeline_components/env.yaml"% __INSTALL_DIR__
  params:
    deseq_wrapper = "%s/deseq_norm.R" % __PC_DIR__
  shell: """
    Rscript {params.deseq_wrapper} '{input.quant}' {input.sample_info} {output.norm}
  """

def normalizeInputFile():
  nConditions = len(set([ dconfig["samples"][s]["replicate_group"] for s in dconfig["samples"] ]))

  if (dconfig["norm_method"] == "tmm") and (nConditions > 1):
    return rules.deseqNorm.output.norm
  else:
    return rules.scriptNorm.output.norm
  #fi
#edef

rule normalize:
  input:
    norm = normalizeInputFile()
  output:
    norm = "%s/quantification.normalized.tsv" % __DIFF_OUTDIR__
  shell: """
    ln -s "{input.norm}" "{output.norm}"
  """

rule deSeqMapTargetNamesTests:
  input:
    targetMap = dconfig["targetMap"],
    tests = rules.deseqTests.output.tests
  output:
    tests = "%s/tests.map.tsv" % __DIFF_OUTDIR__
  run:
    import utils
    utils.mapTargetNames(input.targetMap, input.tests, output.tests)

rule deSeqMapTargetNamesQuant:
  input:
    targetMap = dconfig["targetMap"],
    quant = rules.normalize.output.norm
  output:
    quant = "%s/quantification.normalized.map.tsv" % __DIFF_OUTDIR__
  run:
    import utils
    utils.mapTargetNames(input.targetMap, input.quant, output.quant)

