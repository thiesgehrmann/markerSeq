import org.arabidopsis.ahocorasick.AhoCorasick
import org.arabidopsis.ahocorasick.SearchResult

import scala.annotation._
import java.io._

package markerQuant {

object Quantify extends ActionObject {

  override val description = "Quantify markers in a fastq file"

  override def main(args: Array[String]) = {
    val options = processArgs(args.toList)

    if (!(( options contains "markers") && (options contains "gaps") && (options contains "fastq"))){
      Utils.error("You must define -m, -g and -f")
      System.exit(1)
    }

    val fastaKmer = Fasta.read(options("markers")).toArray
    val fastaGaps = Fasta.read(options("gaps")).toArray
    val k         = options("k").toInt
    val sSpecific = if (options("strandSpecific") == "True") true else false
    val fastq     = options("fastq").split(',').map(Fastq.read)
    val outFile   = options("out")
    val counts    = new Utils.CountMap[String]

    val tree = if (sSpecific) { Quantification.genTree(fastaKmer, fastaGaps, k) } else { Quantification.genTree(fastaKmer ++ fastaKmer.map(_.revcomp), fastaGaps ++ fastaGaps.map(_.revcomp), k) }
    val trees = if (!sSpecific && fastq.length > 1) {
        Array(tree, tree)
      } else if (sSpecific && fastq.length > 1) {
        Array(tree, Quantification.genTree(fastaKmer.map(_.revcomp), fastaGaps, k))
      } else if (!sSpecific && fastq.length == 1) {
        Array(tree)
      } else {
        Array(tree)
      }
    

    Utils.message("Counting markers")
    while(fastq.forall(_.hasNext)){
      val reads   = fastq.map(_.next).toArray
      val markers = Quantification.findInTree(trees, reads).toSet
      counts.add(markers)
    }

    val outfd = new PrintWriter(new FileWriter(outFile, false))
    fastaKmer.map(_.description).foreach{ id =>
      outfd.write("%s\t%d\n".format(id, counts(id)))
    }
    outfd.close()

  }

  val defaultArgs = Map("strandSpecific" -> "False",
                        "out" -> "./quantification.tsv",
                        "k" -> "21")

  def processArgs(args: List[String]) : Map[String,String] = {

    @tailrec def processArgsHelper(args: List[String], options: Map[String,String]): Map[String,String] = {

      args match {
        case "-m" :: value :: tail => {
          processArgsHelper(tail, options ++ Map("markers" -> value))
        }
        case "-g" :: value :: tail => {
          processArgsHelper(tail, options ++ Map("gaps" -> value))
        }
        case "-f" :: value :: tail => {
          processArgsHelper(tail, options ++ Map("fastq" -> value))
        }
        case "-o" :: value :: tail => {
          processArgsHelper(tail, options ++ Map("out" -> value))
        }
        case "-k" :: value :: tail => {
          processArgsHelper(tail, options ++ Map("k" -> value))
        }
        case "-s" :: tail => {
          processArgsHelper(tail, options ++ Map("strandSpecific" -> "True"))
        }
        case opt :: tail => {
          Utils.warning("Option '%s' unknown.".format(opt))
          processArgsHelper(tail, options)
        }
        case Nil => { options }
      }

    }

    processArgsHelper(args, defaultArgs)

  }  

  override def usage = {

  }

}

}