(* ::Package:: *)

(* ::Chapter:: *)
(*D5+ High REs*)


(* ::Text:: *)
(*2/22/2019*)


(* ::Text:: *)
(*High Res D5+*)


(* ::Subsection:: *)
(*Common*)


(* ::Text:: *)
(*These symbols get shared across all the scripts*)


$saDVR = $D5DVR;
$r1r2DVR = $D2DVR;
$r1r21DDVR = $D2SingleDVR;

$fullPot = H5FullInterpPot;
$fullDipoleSurf = $H5DipoleSurfaceInterps;

$r1r2POPotential = h2SinglePot;



(* ::Subsubsubsection::Closed:: *)
(*Set Basis Options*)


$saBasisSize = 90;
$r1r2BasisSize = 35;
$r1r2SCFBasisSize = 60;



(* ::Subsubsubsection::Closed:: *)
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



(* ::Subsubsubsection::Closed:: *)
(*Chunking*)


chunkCount = 10; (* make sure the saGrid is divisible by this... *)



(* ::Subsubsubsection::Closed:: *)
(*State Specs*)


oneQuantumPhaseCorrection = {1, -1};
twoQuantaPhaseCorrection = {1, -1, 1};

