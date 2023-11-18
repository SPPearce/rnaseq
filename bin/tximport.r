#!/usr/bin/env Rscript

# Written by Lorena Pantano and released under the MIT license.

library(SummarizedExperiment)
library(tximport)

args = commandArgs(trailingOnly=TRUE)
if (length(args) < 4) {
    stop("Usage: tximport.r <coldata> <path> <sample_name> <quant_type> <tx2gene_path>", call.=FALSE)
}

coldata = args[1]
path = args[2]
sample_name = args[3]
quant_type = args[4]
tx2gene_path = args[5]

prefix = sample_name

info = file.info(tx2gene_path)
if (info$size == 0) {
    tx2gene = NULL
} else {
    rowdata = read.csv(tx2gene_path, sep="\t", header = FALSE)
    colnames(rowdata) = c("tx", "gene_id", "gene_name")
    tx2gene = rowdata[,1:2]
}

pattern <- ifelse(quant_type == "kallisto", "abundance.tsv", "quant.sf")
fns = list.files(path, pattern = pattern, recursive = T, full.names = T)
names = basename(dirname(fns))
names(fns) = names

if (file.exists(coldata)) {
    coldata = read.csv(coldata, sep="\t")
    coldata = coldata[match(names, coldata[,1]),]
    coldata = cbind(files = fns, coldata)
} else {
    message("ColData not available: ", coldata)
    coldata = data.frame(files = fns, names = names)
}

dropInfReps = quant_type == "kallisto"

txi = tximport(fns, type = quant_type, txOut = TRUE, dropInfReps = dropInfReps)
rownames(coldata) = coldata[["names"]]
extra = setdiff(rownames(txi[[1]]),  as.character(rowdata[["tx"]]))
if (length(extra) > 0) {
    rowdata = rbind(rowdata, data.frame(tx=extra, gene_id=extra, gene_name=extra))
}
rowdata = rowdata[match(rownames(txi[[1]]), as.character(rowdata[["tx"]])),]
rownames(rowdata) = rowdata[["tx"]]
se = SummarizedExperiment(assays = list(counts = txi[["counts"]], abundance = txi[["abundance"]], length = txi[["length"]]),
                        colData = DataFrame(coldata),
                        rowData = rowdata)
if (!is.null(tx2gene)) {
    gi = summarizeToGene(txi, tx2gene = tx2gene)
    gi.ls = summarizeToGene(txi, tx2gene = tx2gene, countsFromAbundance = "lengthScaledTPM")
    gi.s = summarizeToGene(txi, tx2gene = tx2gene, countsFromAbundance = "scaledTPM")
    growdata = unique(rowdata[,2:3])
    growdata = growdata[match(rownames(gi[[1]]), growdata[["gene_id"]]),]
    rownames(growdata) = growdata[["tx"]]
    gse = SummarizedExperiment(assays = list(counts = gi[["counts"]], abundance = gi[["abundance"]], length = gi[["length"]]),
                                colData = DataFrame(coldata),
                                rowData = growdata)
    gse.ls = SummarizedExperiment(assays = list(counts = gi.ls[["counts"]], abundance = gi.ls[["abundance"]], length = gi.ls[["length"]]),
                                colData = DataFrame(coldata),
                                rowData = growdata)
    gse.s = SummarizedExperiment(assays = list(counts = gi.s[["counts"]], abundance = gi.s[["abundance"]], length = gi.s[["length"]]),
                                colData = DataFrame(coldata),
                                rowData = growdata)
}

build_table = function(se.obj, slot) {
    cbind(rowData(se.obj)[,1:2], assays(se.obj)[[slot]])
}

if(exists("gse")){
    write.table(build_table(gse, "abundance"), paste(c(prefix, "gene_tpm.tsv"), collapse="."), sep="\t", quote=FALSE, row.names = FALSE)
    write.table(build_table(gse, "counts"), paste(c(prefix, "gene_counts.tsv"), collapse="."), sep="\t", quote=FALSE, row.names = FALSE)
    write.table(build_table(gse.ls, "abundance"), paste(c(prefix, "gene_tpm_length_scaled.tsv"), collapse="."), sep="\t", quote=FALSE, row.names = FALSE)
    write.table(build_table(gse.ls, "counts"), paste(c(prefix, "gene_counts_length_scaled.tsv"), collapse="."), sep="\t", quote=FALSE, row.names = FALSE)
    write.table(build_table(gse.s, "abundance"), paste(c(prefix, "gene_tpm_scaled.tsv"), collapse="."), sep="\t", quote=FALSE, row.names = FALSE)
    write.table(build_table(gse.s, "counts"), paste(c(prefix, "gene_counts_scaled.tsv"), collapse="."), sep="\t", quote=FALSE, row.names = FALSE)
}

write.table(build_table(se, "abundance"), paste(c(prefix, "transcript_tpm.tsv"), collapse="."), sep="\t", quote=FALSE, row.names = FALSE)
write.table(build_table(se, "counts"), paste(c(prefix, "transcript_counts.tsv"), collapse="."), sep="\t", quote=FALSE, row.names = FALSE)

# Print sessioninfo to standard out
citation("tximeta")
sessionInfo()

