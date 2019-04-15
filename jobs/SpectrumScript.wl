(* ::Package:: *)

(* ::Chapter:: *)
(*Spectrum Script*)


(* ::Text:: *)
(*3/3/2019*)


(* ::Text:: *)
(*Calculate spectrum of specified H5+ system*)


(* ::Section:: *)
(*Average Field (Adiabatic Treatment)*)


(* ::Text:: *)
(*We'll protect ourselves by sticking this $HistoryLength = 0 here... (for local use only)*)


$HistoryLength = 0;
Clear @@ Unprotect[Out];


(* ::Text:: *)
(*On the server do this:*)


$runContext = $ScriptCommandLine[[-1]];


PacletManager`PacletDirectoryAdd["/gscratch/chem/b3m2a1/Mathematica/Paclets"];
$Path = DeleteDuplicates@Append[$Path, "/gscratch/chem/b3m2a1/H5+/Common"];
$out = 
  OpenWrite[
    FileNameJoin@{"outs", "out_" <> ToLowerCase[$runContext] <> ".txt"}
    ];
$Output = 
   Prepend[$Output, $out];
$log = 
  OpenWrite[
    FileNameJoin@{"logs", "log_" <> ToLowerCase[$runContext] <> ".txt"}
    ];
$Messages = 
  Join[{$log, $out}, $Messages];


(* ::Subsection:: *)
(*Set Up Environment*)


Do[If[StringEndsQ[$Context, "`Private`"], End[]], 10];
Do[If[$Context =!= "Global`", EndPackage[]],  10];
BeginPackage[$runContext <> "`"];


(* ::Subsubsection::Closed:: *)
(*Declare Exported Symbols*)


(* ::Text:: *)
(*All of these will end up being dumped to file*)


$OverlapMatrices::usage = 
  "The overlap matrices used in the coupling";
$Wavefunctions::usage = "The 4D wavefunctions used in the end";
$FullWavefunctions::usage = 
  "The full set of 4D wavefunctions generated";
$ZeroPointEnergies::usage = "The ZPEs of all the wavefunctions";
$RawSpectra::usage = "The raw data used for building the spectra";
$Spectra::usage = "The chunks of the spectra generated";



(* ::Subsubsection::Closed:: *)
(*Declare Package Symbols*)


(* ::Text:: *)
(*These are shared between the scripts and should be changed up to get new behavior*)


BeginPackage["`Package`"];


(* ::Subsubsubsection::Closed:: *)
(*Inputs*)


$fullPot::usage = "The 4D potential for the problem";
$fullDipoleSurf::usage = "The 4D dipole surfaces for the problem";


(* ::Subsubsubsection::Closed:: *)
(*Basis Options*)


$saBasisSize;
$saExtendedBasisScaling;
$r1r2BasisSize;
$r1r2SCFBasisSize;


(* ::Subsubsubsection::Closed:: *)
(*Chunking*)


chunkCount;


(* ::Subsubsubsection::Closed:: *)
(*State Specs*)


oneQuantumPhaseCorrection;
twoQuantaPhaseCorrection;


(* ::Subsubsubsection::Closed:: *)
(*DVRs*)


$saDVR::usage = "The DVR for the s/a problem";
$r1r2DVR::usage = "The DVR for the r1/r2 problem";
$r1r21DDVR::isage = "The DVR to the 1D r1 or r2 problem";


(* ::Subsubsubsection::Closed:: *)
(*End*)


EndPackage[];


(* ::Subsection:: *)
(*Begin Private Section*)


Begin["`Private`"];


(* ::Text:: *)
(*This'll load some settings that need to load *before* SpectrumScript*)


Begin["`DoublePrivate`"];


Quiet@Get[
 FileNameJoin@{
   DirectoryName[$ScriptCommandLine[[-2]]],
   StringSplit[$Context, "`"][[1]]<> ".wl"
   }
 ]


If[ValueQ[$calculationType], H5Core`$H5CalculationMode = $calculationType];


End[];


<<SpectrumScriptPackage`


(* ::Subsection:: *)
(*Common*)


(* ::Text:: *)
(*These symbols get shared across all the scripts*)


Get[
 FileNameJoin@{
   DirectoryName[$ScriptCommandLine[[-2]]],
   StringSplit[$Context, "`"][[1]]<> ".wl"
   }
 ]


(* ::Subsubsection::Closed:: *)
(*SA Grid*)


If[IntegerQ[$saBasisSize], 
  $saBasisSize = {$saBasisSize, $saBasisSize}
  ]


saMainGrid = $saDVR["Grid", "Points" -> $saBasisSize];
saGrid = saMainGrid["Points"];


(* ::Subsubsection::Closed:: *)
(*SA Extended Grid*)


$saExtendedBasisSize=
  Replace[$saExtendedBasisSize, Except[_Integer|{_Integer, _Integer}]->$saBasisSize];
If[IntegerQ[$saExtendedBasisSize], 
  $saExtendedBasisSize = {$saBasisSize, $saBasisSize}
  ]


saExtendedGridObject = 
  $saDVR["Grid", 
   "Points" -> $saExtendedBasisSize
   ];
saExtendedGrid = saExtendedGridObject["Points"];
$saNewBasiSize = $saExtendedBasisSize;


(* ::Subsubsection::Closed:: *)
(*r1r2Potential*)


r1r2Potential // Clear
r1r2Potential[{a_, s_}] :=
  getR1R2Potential[$fullPot, {a, s}];


(* ::Subsubsection::Closed:: *)
(*r1r2GridObject*)


r1r2GridObject = $r1r2DVR["Grid"];
r1r2Grid = r1r2GridObject["Grid"];
r1r2GridPts = r1r2GridObject["Points"];


(* ::Subsection:: *)
(*Core Data*)


(* ::Subsubsection::Closed:: *)
(*r1r2Wavefunctions*)


(* ::Text:: *)
(*Get H2 wavefunctions parametrized by (s, a)*)


debugPrint["Generating r1/r2 wavefunctions..."]


(* ::Subsubsubsection::Closed:: *)
(*r1r2Wavefunctions*)


r1r2Wavefunctions // cachedLoad@
   getR1R2Wavefunctions[
    $r1r2DVR, r1r2Potential, 
    r1r2GridObject, saMainGrid
    ];


(* ::Subsubsubsection::Closed:: *)
(*r1r2PotMinima*)


r1r2PotMinima // cachedLoad@
   getR1R2PotentialMin[
    r1r2Potential, 
    r1r2GridObject, 
    saMainGrid
    ];


(* ::Subsubsubsection::Closed:: *)
(*cleanedR1R2Wavefunctions*)


cleanedR1R2Wavefunctions = 
  AssociationMap[
    With[{pt=#[[1]], v=#[[2]]},
      pt->If[!gridMemberQ[pt, $fullPot], $Failed, v]
      ]&
    ]@r1r2Wavefunctions;


(* ::Subsubsubsection::Closed:: *)
(*debugPrint*)


debugPrint["Generated r1/r2 wavefunctions"]


(* ::Subsubsection:: *)
(*SCF Procedure*)


(* ::Subsubsubsection::Closed:: *)
(*SCF Wavefunction Computation*)


(* ::Subsubsubsubsection::Closed:: *)
(*r1r2SCFGrid*)


r1r2SCFGrid = scfGrid[$r1r2DVR, $r1r2SCFBasisSize];


(* ::Subsubsubsubsection::Closed:: *)
(*r1r2SCFStates*)


r1r2SCFStates =
  {
   {1, 1},
   {1, 2}, {2, 1}, 
   {3, 1}, {2, 2}, {1, 3},
   {4, 1}, {2, 3}, {3, 2}, {1, 4}
   };


(* ::Subsubsubsubsection::Closed:: *)
(*debugPrint*)


debugPrint["Generating SCF coefficients..."]


(* ::Subsubsubsubsection::Closed:: *)
(*coeffChunkingLength*)


coeffChunkingLength =
  Floor[(Times@@$saBasisSize)/chunkCount];


(* ::Subsubsubsubsection::Closed:: *)
(*loadChunk*)


loadChunk[n_]:=
  With[
    {
     chunk =
      ToExpression[
       "coeffChunk" <> ToString[n], 
       StandardForm,
       Function[Null,  Clear[#]; #, HoldAllComplete]
       ],
     grid = 
      saGrid[[
        1 + (n - 1)*coeffChunkingLength ;; 
        n*coeffChunkingLength
        ]]
     },
    cachedLoad[
     chunk,
     AssociationMap[
      scfCoeffData[
        $r1r21DDVR,
        $r1r2DVR,
        r1r2SCFGrid,
        r1r2Potential,
        r1r2SCFStates,
        #,
        $r1r2SCFBasisSize
        ] &, 
      grid
      ]
     ];
    chunk
    ]


(* ::Subsubsubsubsection::Closed:: *)
(*coefficientData*)


coefficientData =
  Module[
    {
      chunks=<||>
      },
    Do[
      chunks = Join[chunks, loadChunk[n]];
      If[Length@chunks == Times@@$saBasisSize,
        Return[chunks, Do]
        ],
      {n, chunkCount}
      ];
    chunks
    ]


(* ::Subsubsubsubsection::Closed:: *)
(*cleanedCoefficientData*)


cleanedCoefficientData =
  AssociationMap[
    With[{pt=#[[1]], v=#[[2]]},
      pt->If[!gridMemberQ[pt, $fullPot], $Failed, v]
      ]&
    ]@coefficientData;


(* ::Subsubsubsubsection::Closed:: *)
(*debugPrint*)


debugPrint["SCF coefficients calculated"]


(* ::Subsubsubsection::Closed:: *)
(*Rephased Data*)


debugPrint["Rephasing SCF wavefunctions"]


(* ::Text:: *)
(*No way to rephase consistently across inconsistent (PODVR) grids...*)


(* ::Subsubsubsubsection::Closed:: *)
(*rephasingData*)


(*rephasingData =
  getPhaseCorrection[
   Values@cleanedR1R2Wavefunctions, 
   Keys[r1r2Wavefunctions], Range[Length@r1r2SCFStates]
   ];*)


(*rephasedR1R2Wavefunctions =
  AssociationThread[
   Keys[r1r2Wavefunctions],
   rephasingData["Wavefunctions"]
   ];*)


(* ::Subsubsubsubsection::Closed:: *)
(*debugPrint*)


debugPrint["Rephasing SCF DVR wavefunctions"]


(* ::Subsubsubsubsection::Closed:: *)
(*phaseInCorrectDVR*)


phaseInCorrectDVR =
  If[AssociationQ[#], #["DVRWavefunctions"], #] & /@ coefficientData;


(* ::Subsubsubsubsection::Closed:: *)
(*dvrPhaseCorrectionVector*)


dvrPhaseCorrectionVector = {1, 1, 1, 1, 1, 1};


(* ::Subsubsubsubsection::Closed:: *)
(*phaseCorrectDVR*)


phaseCorrectDVR // cachedLoad[
   getPhaseCorrection[
     If[AssociationQ[#], #["DVRWavefunctions"], #] & /@
       cleanedCoefficientData // Values, 
     Keys[r1r2Wavefunctions],
     Range[Length[dvrPhaseCorrectionVector]],
     dvrPhaseCorrectionVector,
     True
     ]["Wavefunctions"]
   ];


(* ::Subsubsubsubsection::Closed:: *)
(*phaseCorrectDVR*)


(*phaseCorrectDVR // cachedLoad[
   getPhaseCorrection[
     If[AssociationQ[#], #["DVRWavefunctions"], #] & /@
       
       coefficientData // Values, 
     Keys[r1r2Wavefunctions],
     {2},
     True
     ]["Wavefunctions"]
   ];*)


(*Print["`` unique points"~TemplateApply~Length[DeleteDuplicates[saExtendedGrid]]]*)


(*phaseCorrectDVR = (* to fake in the extension to the grid *)
  Values@Merge[
    {
      AssociationThread[Round[Keys[cleanedCoefficientData], .0001], phaseCorrectDVR],
      Thread[Round[saExtendedGrid, .0001]->$Failed]
      },
    First
    ]*)


(*If[Length[phaseCorrectDVR]=!=Length[saExtendedGrid],
  Throw[
    "Extended DVR grid doesn't partially coincide with base coefficient grid. \
`` points against `` points"~TemplateApply~{
    Length[phaseCorrectDVR],
    Length[saExtendedGrid]
    }
    ]
  ]*)


(* ::Subsubsubsubsection::Closed:: *)
(*debugPrint SCF*)


debugPrint["Rephasing SCF SCF wavefunctions"]


(* ::Subsubsubsubsection::Closed:: *)
(*scfPhaseCorrectionVector*)


scfPhaseCorrectionVector = {1, 1, 1, 1, 1, 1};


(* ::Subsubsubsubsection::Closed:: *)
(*phaseCorrectSCF*)


phaseCorrectSCF // cachedLoad[
   getPhaseCorrection[
     If[AssociationQ[#], #["SCFWavefunctions"], #] & /@
       cleanedCoefficientData // Values, 
     Keys[r1r2Wavefunctions],
     Range[Length[scfPhaseCorrectionVector]],
     scfPhaseCorrectionVector,
     True
     ]["Wavefunctions"]
   ];


(* ::Subsubsubsubsection::Closed:: *)
(*phaseCorrectSCF*)


(*phaseCorrectSCF // cachedLoad[
   getPhaseCorrection[
     If[AssociationQ[#], #["SCFWavefunctions"], #] & /@
       coefficientData // Values, 
     Keys[r1r2Wavefunctions],
    {2},
     True
     ]["Wavefunctions"]
   ]*)


(*phaseCorrectSCF = (* to fake in the extension to the grid *)
  Values@Merge[
    {
      AssociationThread[Keys[cleanedCoefficientData], phaseCorrectSCF],
      Thread[saExtendedGrid->$Failed]
      },
    First
    ];*)


(*If[Length[phaseCorrectSCF]=!=Length[saExtendedGrid],
  Throw[
    "Extended SCF grid doesn't partially coincide with base coefficient grid. \
`` points against `` points"~TemplateApply~{
    Length[phaseCorrectSCF],
    Length[saExtendedGrid]
    }
    ]
  ]*)


(* ::Subsubsubsubsection::Closed:: *)
(*debugPrint*)


debugPrint["Got `` SCF wavefunctions"~TemplateApply~Length[phaseCorrectSCF]]


(* ::Subsubsubsubsection::Closed:: *)
(*debugPrint*)


debugPrint["Rephased SCF wavefunctions"]


(* ::Subsubsubsection::Closed:: *)
(*SCF Phases 1 Quantum*)


debugPrint["Generating one quantum overlap matrix"]


(*{overlapMatrixOneQuantum, goodSparseOneQuantum}*)
goodSparseOneQuantum =
  getSCFOverlapMatrix[
   phaseCorrectSCF, phaseCorrectDVR, 
   {2, 3}, 
   oneQuantumPhaseCorrection,
   Keys[coefficientData], 
   saExtendedGrid,
   {-1, -1}
   ];


dumpSymbol[goodSparseOneQuantum]


(* ::Subsubsubsection:: *)
(*SCF Phases 2 Quanta*)


debugPrint["Generating two quanta overlap matrix"]


(*{overlapMatrixTwoQuanta, goodSparseTwoQuanta}*)
goodSparseTwoQuanta =
  getSCFOverlapMatrix[
    phaseCorrectSCF, phaseCorrectDVR, 
    {4, 5, 6}, 
    twoQuantaPhaseCorrection,
    Keys[coefficientData], saExtendedGrid,
    {1, -1, 1}
    ];



dumpSymbol[goodSparseTwoQuanta]


(* ::Subsubsubsection::Closed:: *)
(*SCF Phases 1 and 2 Quanta*)


(*debugPrint["Generating one and two quanta overlap matrix"]
{overlapMatrixOneAndTwoQuanta, goodSparseOneAndTwoQuanta} =
  getSCFOverlapMatrix[
   phaseCorrectSCF, 
   phaseCorrectDVR, 
   {2, 3, 4, 5, 6}, 
   Join[oneQuantumPhaseCorrection, twoQuantaPhaseCorrection],
   Keys[coefficientData], saExtendedGrid
   ];
*)


(* ::Subsubsubsection::Closed:: *)
(*$OverlapMatrices*)


$OverlapMatrices =
  <|
   "OneQuantum" -> goodSparseOneQuantum,
   "TwoQuanta" -> goodSparseTwoQuanta(*,
   "OneAndTwoQuanta" -> overlapMatrixOneAndTwoQuanta*)
   |>;


(* ::Subsection:: *)
(*Wavefunctions*)


(* ::Subsubsection::Closed:: *)
(*Results*)


(* ::Subsubsubsection::Closed:: *)
(*No Quanta*)


debugPrint["Generating 4D wavefunctions..."]


debugPrint["Generating No Quanta Wavefunction"]
noQuantaWfns // cachedLoad@
 getWavefunctions[
  r1r2Wavefunctions,
  $saDVR, 
  ConstantArray[1, (Times@@$saNewBasiSize)*{1, 1} ], 
  saExtendedGridObject,
  1
  ]


(* ::Subsubsubsection::Closed:: *)
(*One Quantum*)


debugPrint["Generating One Quantum Wavefunction"]
debugPrint[
  "Dimensions of coupling matrix `` of type `` at `` bytes"~TemplateApply~{
    Dimensions[goodSparseOneQuantum],
    Head[goodSparseOneQuantum], 
    ByteCount[goodSparseOneQuantum]
    }
  ]


oneQuantumWfns // cachedLoad@
 getWavefunctions[
  r1r2Wavefunctions,
  $saDVR, 
  goodSparseOneQuantum, 
  saExtendedGridObject,
  2, 3
  ]


(* ::Subsubsubsection::Closed:: *)
(*Two Quanta*)


debugPrint["Generating Two Quanta Wavefunction"]
debugPrint[
  "Dimensions of coupling matrix `` of type `` at `` bytes"~TemplateApply~{
    Dimensions[goodSparseTwoQuanta],
    Head[goodSparseTwoQuanta], 
    ByteCount[goodSparseTwoQuanta]
    }
  ]


twoQuantaWfns // cachedLoad@
 getWavefunctions[
  r1r2Wavefunctions,
  $saDVR, 
  goodSparseTwoQuanta, 
  saExtendedGridObject,
  4, 5, 6
  ]


(* ::Subsubsubsection::Closed:: *)
(*One and Two Quanta*)


(*debugPrint["Generating One/Two Quanta Wavefunction"]
oneAndTwoQuantaWfns =
 getWavefunctions[
  r1r2Wavefunctions,
   $saDVR, 
  goodSparseOneAndTwoQuanta, 
  saExtendedGridObject, 
  2, 3, 4, 5, 6
  ]
*)


(* ::Subsubsubsection::Closed:: *)
(*Adiabatic States*)


debugPrint["Generating Adiabatic Wavefunctions"]
adiabaticWfns =
  getWavefunctions[
     r1r2Wavefunctions,
     $saDVR, 
     ConstantArray[1, (Times@@$saNewBasiSize)*{1, 1} ], 
     saExtendedGridObject,
     #
     ] & /@ Range[2, 10];


(* ::Subsubsubsection::Closed:: *)
(*Results*)


debugPrint["4D wavefunctions generated"]


$Wavefunctions =
  <|
   "NoQuanta" -> noQuantaWfns,
   "OneQuantum" -> oneQuantumWfns,
   "TwoQuanta" -> twoQuantaWfns
   |>;


$FullWavefunctions =
  Join[
   $Wavefunctions,
   <|
    "Adiabatic" -> adiabaticWfns(*,
    "OneAndTwoQuanta" -> oneAndTwoQuantaWfns*)
    |>
   ];


$EnergyShifts =
  Map[#["Energies"][[1]] &, $FullWavefunctions] - 
   noQuantaWfns["Energies"][[1]];


$ZeroPointEnergies =
  AssociationThread[
   Keys@$FullWavefunctions,
   Map[#["Energies"][[1]] &, Values@$FullWavefunctions] -
    Map[Min[averagedPot[r1r2Wavefunctions, #]] &, 
     Join[{1, 2, 4, 2}, Range[2, 10]]
     ]
   ];


(* ::Subsubsection::Closed:: *)
(*Projections*)


debugPrint["Pulling projections from wavefunctions"]


(* ::Subsubsubsection::Closed:: *)
(*One Quantum*)


oneQuantumProjections =
  pullProjections[oneQuantumWfns, saMainGrid, {2, 3}];


(* ::Subsubsubsection::Closed:: *)
(*Two Quanta*)


twoQuantaProjections =
  pullProjections[twoQuantaWfns, saMainGrid, {4, 5, 6}];


(* ::Subsubsubsection::Closed:: *)
(*One and Two Quanta*)


(*oneAndTwoQuantaProjections =
  pullProjections[oneAndTwoQuantaWfns, saMainGrid, {2, 3, 4, 5, 6}];
*)


debugPrint["Projections pulled"]


(* ::Subsection:: *)
(*Spectrum*)


(* ::Subsubsection::Closed:: *)
(*Transition Moments*)


debugPrint["Generating transition moments..."]


(* ::Subsubsubsection::Closed:: *)
(*Build Base Dipole Vectors*)


newInterp = rebuildInterpolation@$fullDipoleSurf[[1]];


r1r2DipoleVectors // cachedLoad[
   getDipoleVecs[r1r2Wavefunctions, r1r2GridPts , newInterp]
   ];


(* ::Subsubsubsection::Closed:: *)
(*Extract Transition Moments*)


(* ::Subsubsubsubsection::Closed:: *)
(*Calc moments*)


r1r2TransitionMoments // cachedLoad[
  getTransitionMoments[
   phaseCorrectDVR,
   r1r2DipoleVectors
   ]
  ]


debugPrint["Generated transition moments"]


(* ::Subsubsubsubsection::Closed:: *)
(*Full moments*)


r1r2GridTMs =
  <|
    "Grid"->Keys[r1r2TransitionMoments],
    "Values"->
      Transpose@
       Map[
        If[# === $Failed, ConstantArray[0., {10, 3}], #] &, 
        Values@r1r2TransitionMoments
        ]
    |>


(* ::Subsubsection::Closed:: *)
(*Intensities*)


debugPrint["Generating spectra"]


(* ::Text:: *)
(*Ground state stuff*)


zaWfn = noQuantaWfns[[1]];


(* ::Subsubsubsection::Closed:: *)
(*Base Wfns*)


(* ::Subsubsubsubsection::Closed:: *)
(*One Quantum*)


(* ::Text:: *)
(*Get sets of projection wavefunctions to moment over*)


oneQuantumTransWfs =
  getTransitionWavefunctions[oneQuantumProjections, zaWfn];


(* ::Subsubsubsubsection::Closed:: *)
(*Two Quanta*)


twoQuantaTransWfs =
  getTransitionWavefunctions[twoQuantaProjections, zaWfn];


(* ::Subsubsubsubsection::Closed:: *)
(*One and Two Quanta*)


(*oneAndTwoQuantaTransWfs =
  getTransitionWavefunctions[oneAndTwoQuantaProjections, zaWfn];
*)


(* ::Subsubsubsection::Closed:: *)
(*Ints*)


noQuantaInts = getIntensities[{noQuantaWfns}, {1}, r1r2GridTMs];
oneQuantumInts = 
  getIntensities[oneQuantumTransWfs, {2, 3}, r1r2GridTMs];
twoQuantaInts = 
  getIntensities[twoQuantaTransWfs, {4, 5, 6}, r1r2GridTMs];
(*oneAndTwoQuantaInts = 
  getIntensities[oneAndTwoQuantaTransWfs, {2, 3, 4, 5, 6}, 
   r1r2GridTMs];*)
adiabaticInts =
  MapIndexed[
   getIntensities[{Join[noQuantaWfns[[;; 1]], #]}, 1 + #2, 
     r1r2GridTMs] &, 
   adiabaticWfns
   ];


(* ::Subsubsection::Closed:: *)
(*Frequencies*)


(* ::Text:: *)
(*We then turn these into intensities and plot them:*)


(* ::Subsubsubsection::Closed:: *)
(*No Quanta*)


noQuantaFreqs = getFreqs[noQuantaWfns, zaWfn];
oneQuantumFreqs = getFreqs[oneQuantumWfns, zaWfn];
twoQuantaFreqs = getFreqs[twoQuantaWfns, zaWfn];
(*oneAndTwoQuantaFreqs = getFreqs[oneAndTwoQuantaWfns, zaWfn];*)
adiabaticFreqs = getFreqs[#, zaWfn] & /@ adiabaticWfns


debugPrint["Spectra generated"]


$RawSpectra =
  <|
   "Frequencies" ->
    Join[
     {
      noQuantaFreqs,
      oneQuantumFreqs,
      twoQuantaFreqs(*,
      oneAndTwoQuantaFreqs*)
      },
     adiabaticFreqs
     ],
   "Intensities" ->
    Join[
     {
      noQuantaInts,
      oneQuantumInts,
      twoQuantaInts(*,
      oneAndTwoQuantaInts*)
      },
     adiabaticInts
     ]
   |>;


(* ::Subsubsection::Closed:: *)
(*Spectra*)


(* ::Text:: *)
(*After we build the transition moments we can plot them:*)


$Spectra =
  buildSpectra[$RawSpectra["Frequencies"], $RawSpectra["Intensities"]];


(* ::Subsection:: *)
(*Dump Environment*)


(* ::Subsubsection::Closed:: *)
(*End Private Context*)


End[];


(* ::Subsubsection::Closed:: *)
(*DumpSave Symbols*)


ToExpression[Names[$Context <> "*"], StandardForm, dumpSymbol]


(* ::Subsubsection::Closed:: *)
(*EndPackage*)


EndPackage[];
