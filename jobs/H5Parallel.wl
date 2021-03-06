(* ::Package:: *)

(* ::Chapter:: *)
(*H5 Parallel*)


(* ::Text:: *)
(*2/22/2019*)


(* ::Text:: *)
(*Parallel H2 groups in H5+*)


(* ::Subsection:: *)
(*Common*)


(* ::Text:: *)
(*These symbols get shared across all the scripts*)


$saDVR = $H5DVR;
$r1r2DVR = $H2DVR;
$r1r21DDVR = $H2SingleDVR;

$fullPot = $H5ParallelFullInterpPot;
$fullDipoleSurf = $H5ParallelDipoleSurfaceInterps;

$r1r2POPotential = h2ParallelSinglePot;



(* ::Subsubsubsection:: *)
(*Set Basis Options*)


$saBasisSize = 60;
$r1r2BasisSize = 25;
$r1r2SCFBasisSize = 60;

$saExtendedBasisSize = 100;


(* ::Subsubsubsection:: *)
(*Set DVR Options*)


$saDVR["RuntimeOptions"] =
  Append[
   $saDVR["RuntimeOptions"],
   "WavefunctionsOptions" -> {
     "ValidateHamiltonian" -> False
     }
   ];
$saDVR["Points"] = {$saBasisSize, $saBasisSize};
$r1r2DVR["RuntimeOptions"] =
  Join[
   $r1r2DVR["RuntimeOptions"],
   {
    "PotentialOptimizationOptions" -> {
      "PotentialFunction" -> $r1r2POPotential,
      "OptimizedBasisSize" -> $r1r2BasisSize
      },
    "WavefunctionsOptions" -> {
      "ValidateHamiltonian" -> False
      }
    }
   ];
$r1r21DDVR["RuntimeOptions"] =
  Append[
   $r1r21DDVR["RuntimeOptions"],
   "WavefunctionsOptions" -> {
     "ValidateHamiltonian" -> False
     }
   ];



(* ::Subsubsubsection:: *)
(*Chunking*)


chunkCount = 10; (* make sure the saGrid is divisible by this... *)



(* ::Subsubsubsection:: *)
(*State Specs*)


oneQuantumPhaseCorrection = {1, -1};
twoQuantaPhaseCorrection = {1, -1, 1};

