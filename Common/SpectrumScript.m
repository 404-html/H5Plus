(* ::Package:: *)

(* Autogenerated Package *)

BeginPackage["SpectrumScript`", {"H5Core`"}];


loadEnvironment::usage="";


(* ::Subsubsubsection::Closed:: *)
(*Caching / Debugging*)



dumpSymbolFile::usage="";
dumpSymbol::usage="";
cachedLoad::usage="";
debugPrint::usage="";


(* ::Subsubsubsection::Closed:: *)
(*r1/r2*)



getR1R2Potential::usage="";
getR1R2PotentialMin::usage="";
getR1R2Wavefunctions::usage="";


(* ::Subsubsubsection::Closed:: *)
(*Phases*)



rephaseThingies::usage="";
rephaseWfns::usage="";
getPhaseCorrection::usage="";
getVectorPhaseCorrection::usage="";


(* ::Subsubsubsection::Closed:: *)
(*Grids*)



gridMemberQ::usage="";


(* ::Subsubsubsection::Closed:: *)
(*Extrap*)



extrapolatedFunction::usage="";


(* ::Subsubsubsection::Closed:: *)
(*SCF*)



scfGrid::usage="";
scfWavefunction::usage="";
scfCoeffData::usage="";


(* ::Subsubsubsection::Closed:: *)
(*Overlaps*)



getSCFOverlapMatrix::usage="";


(* ::Subsubsubsection::Closed:: *)
(*Wavefunctions*)



coupledKineticEnergy::usage="";
averagedPot::usage="";
coupledPot::usage="";
coupledGrid::usage="";
getWavefunctions::usage="";
pullProjections::usage="";


(* ::Subsubsubsection::Closed:: *)
(*Spectra*)



rebuildInterpolation::usage="";
interpolatedDipoleSurface::usage="";
getDipoleVecs::usage="";
getTransitionMoments::usage="";
getTransitionWavefunctions::usage="";
getIntensities::usage="";
getFreqs::usage="";
buildSpectra::usage="";


Begin["`Private`"];


<<ChemTools`DVR`;
<<ChemTools`Wavefunctions`;
<<ChemTools`DataStructures`;
<<ChemTools`Spectroscopy`;
(* a preload because .mx can do weird things sometimes *)
CoordinateGridObject;
GridFunctionObject;
WavefunctionsObject;


(* ::Subsubsection::Closed:: *)
(*Caching / Loading*)



(* ::Subsubsubsection::Closed:: *)
(*getDumpBase*)



getDumpBase[]:=
  With[{dir=H5PackageFile["results", StringSplit[$Context, "`"][[1]]]},
    Quiet@CreateDirectory[dir];
    dir
    ];


(* ::Subsubsubsection::Closed:: *)
(*dumpSymbolFile*)



dumpSymbolFile[symbol_Symbol]:=
  FileNameJoin@{getDumpBase[], SymbolName[Unevaluated[symbol]]<>".mx"};
dumpSymbolFile~SetAttributes~HoldFirst;


(* ::Subsubsubsection::Closed:: *)
(*dumpSymbol*)



dumpSymbol[symbol_Symbol]:=
  Export[dumpSymbolFile[symbol], symbol];
dumpSymbol~SetAttributes~HoldFirst


(* ::Subsubsubsection::Closed:: *)
(*cachedLoad*)



cachedLoad[symbol_Symbol, expr_]:=
  With[{dsf=dumpSymbolFile[symbol]},
    If[FileExistsQ[dsf], 
      symbol=Import[dsf],
      symbol=expr;
      Export[dsf, symbol];
      symbol
      ]
    ];
cachedLoad[expr_]:=
  Function[Null, cachedLoad[#, expr], HoldAllComplete];
cachedLoad~SetAttributes~HoldAllComplete;


(* ::Subsubsubsection::Closed:: *)
(*debugPrint*)



$debugMode=True;
debugPrint[a___]:=
If[$debugMode, Print[a]];


(* ::Subsubsection::Closed:: *)
(*Misc*)



(* ::Subsubsubsection::Closed:: *)
(*gridMemberQ*)



gridMemberQ[pts:_List?(MatrixQ[#, Internal`RealValuedNumberQ]&), range_List, transf_]:=
  Module[
    {
      tpts = transf@pts,
      checker = RegionMember[Cuboid@@Transpose[range]]
      },
    checker/@tpts
    ];
gridMemberQ[pts:_List?(MatrixQ[#, Internal`RealValuedNumberQ]&), range_List]:=
  Module[
    {
      tfunc,
      r2
      },
      Switch[Dimensions[pts][[-1]],
        2,
          tfunc = 
            Transpose[RotationMatrix[-\[Pi]/4].Transpose[#]]&;
          r2 = range[[-2;;]],
        4,
          tfunc = 
            Transpose[ArrayFlatten[{{IdentityMatrix[2], 0}, {0, RotationMatrix[-\[Pi]/4]}}].Transpose[#]]&;
          r2 = range,
        _,
          tfunc = Identity;
          r2 = range
        ];
    gridMemberQ[pts, r2, tfunc]
  ];
gridMemberQ[pts:_List?(VectorQ[#, Internal`RealValuedNumberQ]&), range_List, transf_]:=
  gridMemberQ[{pts}, range, transf][[1]];
gridMemberQ[pts:_List?(VectorQ[#, Internal`RealValuedNumberQ]&), range_List]:=
  gridMemberQ[{pts}, range][[1]];
gridMemberQ[pts_, i_InterpolatingFunction, transf_]:=
  gridMemberQ[pts, i["Domain"], transf];
gridMemberQ[pts_, i_InterpolatingFunction]:=
  gridMemberQ[pts, i["Domain"]]


(* ::Subsubsubsection::Closed:: *)
(*extrapolatedFunction*)



extrapolatedFunction//Clear
extrapolatedFunction[
  fn_, 
  cutOffs: {
    Except[_Integer?(0<#<1000&), _?NumericQ], 
    Except[_Integer?(0<#<1000&), _?NumericQ]
    } : {-10^8, 5*10^8} 
    (* "bad values" should be indicated by larger or smaller numbers than this *),
  pointSampling:{_Scaled|_Integer, _Scaled|_Integer}:{Scaled[.1], Scaled[.2]},
  fitForms: {_Function, _Function} : 
    {
      (* eh fuck this form it's fine to just use a 6-th order polynomial to fit the _entire_ potential *)
      <|
        "Form"->
          {
            C[2] + C[1]*Exp[-C[3]*#], 
            {C[3]>0(*, C[2] + C[1]*Exp[-C[3]*Point] \[Equal] Value*)}
            },
        "Parameters"->Array[C, 3]
        |>&, 
      <|"Form"->(C[2]+C[1]/((#)^4)), "Parameters"->Array[C, 2]|>&
      },
  ops:OptionsPattern[]
  ]:=
  Module[
    {
      trueGridVals = 
        Pick[fn,
          UnitStep[cutOffs[[2]] - fn[[All, 3]]]*
            UnitStep[fn[[All, 3]] - cutOffs[[1]]],
          1
          ],
      trueGridRot,
      basePot,
      rotWfnGrid,
      trueRotSubGrids,
      rotSubGrids,
      fits,
      monkeyPatch,
      gridVals,
      gpts,
      missing,
      gptsRegrouped,
      fullGridRegrouped,
      patchedPts
      },
    rotWfnGrid = 
      fn[[All, ;;2]]//RotationMatrix[-\[Pi]/4].Transpose[#]&//Transpose;
    trueGridRot = 
      Join[
        trueGridVals[[All, ;;2]]//RotationMatrix[-\[Pi]/4].Transpose[#]&//Transpose, 
        trueGridVals[[All, {3}]], 
        2
        ];
    rotSubGrids =
      GroupBy[rotWfnGrid, (Round[#[[1]], .00001]&)->(#[[;;2]]&), SortBy[#[[2]]&]];
    trueRotSubGrids = 
      GroupBy[trueGridRot, (Round[#[[1]], .00001]&), SortBy[#[[2]]&]];
    monkeyPatch[f_, r_, c_]:=
      (*Evaluate[c+f[#-r]]&*)f;
    fits = 
      Block[{r, forms, nl = pointSampling[[1]], nr = pointSampling[[2]]},
        forms = Through[fitForms[r]];
        MapThread[
          With[{data = #, r0 = #3[[1]], c = #3[[2]]},
            monkeyPatch[
              If[ListQ@#2,
                LinearModelFit[data, #2, r, ops]["Function"],
                Replace[
                  Thread[
                    ToExpression[
                      "par"<>ToString[#]&/@Range[Length[#2["Parameters"]]], 
                      StandardForm, 
                      Hold
                      ],
                    Hold
                    ],
                  Hold[p__]:>
                    Block[p,
                      With[{model = 
                        #2["Form"]/.Join[
                            Thread[#2["Parameters"]->p],
                            {Point->r0, Value->c}
                            ]},
                        NonlinearModelFit[
                          data,
                          model, 
                          p, 
                          r,
                          ops
                          ]["Function"]
                        ]
                      ]
                  ]
                ],
              r0,
              c
              ]
            ]&,
          {
            {
              #[[
                ;;Replace[nl,
                    Scaled[i_]:>Floor[i*Length[#]]
                    ],
                {2, 3}
                ]],
              #[[
                -Replace[nr,
                    Scaled[i_]:>Floor[i*Length[#]]
                    ];;,
                {2, 3}
                ]]
              },
            forms,
            #[[{1, -1}, {2, 3}]]
            }
          ]&/@trueRotSubGrids
        ];
      gridVals = MapThread[
        With[
          {
            minFit = #[[1]], maxFit = #[[2]], 
            ptRaw = #3[[All, 2]],
            goodBounds = MinMax @ #2[[All, 2]]},
          Join[
            With[{pts=Pick[ptRaw, UnitStep[goodBounds[[1]] - ptRaw], 1]},
              Transpose[{
                ConstantArray[#3[[1, 1]], Length@pts],
                pts, 
                minFit@pts
                }]
              ],
            #2,
            With[{pts=Pick[ptRaw, ptRaw - goodBounds[[2]]//UnitStep, 1]},
              Transpose[{
                ConstantArray[#3[[1, 1]], Length@pts],
                pts, 
                maxFit@pts
                }]
              ]
            ]
          ]&,
        {
          fits,
          trueRotSubGrids,
          KeyTake[rotSubGrids, Keys[trueRotSubGrids]]
          }
        ];
      gpts=
        Flatten[
          Values[gridVals],
          1
          ];
      gpts=
        DeleteDuplicatesBy[
          Join[
            #,  
            Transpose[{#[[All, 2]], #[[All, 1]], #[[All, 3]]}]
            ]&@
            gpts,
          Round[#[[;;2]], .001]&
          ];
      gpts=
        Join[
            RotationMatrix[Pi/4].Transpose[gpts[[All, ;;2]]]//Transpose, 
            gpts[[All, {3}]],
            2
            ];
      gptsRegrouped = GroupBy[gpts, Round[#[[1]], .001]&];
      fullGridRegrouped = GroupBy[fn[[All, ;;2]], Round[#[[1]], .001]&];
      patchedPts=
        MapThread[
          If[Length[#]=!=Length[#2],
            Join[
              #2[[All, ;; 2]],
              List/@
                Interpolation[#[[All, {2, 3}]], 
                    "ExtrapolationHandler"->{Automatic, "WarningMessage"->False}][
                  #2[[All, 2]]
                  ],
              2
              ],
            #
            ]&,
          {
            KeySort@gptsRegrouped,
            KeySort@fullGridRegrouped
            }
          ];
      Round[
        Developer`ToPackedArray@
          Flatten[Values[patchedPts], 1],
        .0001
        ](*//Interpolation*)
      ]


(* ::Subsubsection::Closed:: *)
(*R1R2 Stuff*)



(* ::Subsubsubsection::Closed:: *)
(*getR1R2Potential*)



getR1R2Potential[fullPot_, {a_, s_}]:=
  If[
    With[
      {
        R1R2=RotationMatrix[-\[Pi]/4].{a, s}, 
        bounds=$H5PotentialRegion[[3]](*fullPot[[1, 3]]*)
        },
      AllTrue[R1R2, bounds[[1]]<=#<bounds[[2]]&]
      ],
    H5VectorizedInterpCut[
      {a, s, Automatic, Automatic}, 
      fullPot, 
      $H5PotentialRegion,
      10.^9, 
      0.
      ],
    $Failed
    ];


(* ::Subsubsubsection::Closed:: *)
(*getR1R2PotentialMin*)



getR1R2PotentialMin[shit_:None, potGenerator_, r1r2grid_, saGrid_]:=
  AssociationMap[
    With[{pot=potGenerator[#]},
      If[pot=!=$Failed,
        Min[pot@r1r2grid["Points"]],
        $Failed
        ]
      ]&,
    saGrid@"Points"
    ]


(* ::Subsubsubsection::Closed:: *)
(*getR1R2Wavefunctions*)



getR1R2Wavefunctions[dvr_, potGenerator_, r1r2grid_, saGrid_]:=
  AssociationMap[
    With[{pot=potGenerator[#]},
      If[pot=!=$Failed,
        dvr[
          "Wavefunctions",
          "PotentialEnergy"->
              SparseArray[Band[{1, 1}]->pot@r1r2grid["Points"]],
          "Grid"->r1r2grid,
          "ArnoldiIterations"->5000,
          "NodelessGroundState"->True
          ],
        $Failed
        ]
      ]&,
    saGrid@"Points"
    ]


(* ::Subsubsection::Closed:: *)
(*Phase Corrections*)



(* ::Subsubsubsection::Closed:: *)
(*rephaseThingies*)



rephaseThingies=
  Compile[{{overlaps, _Real, 1}, {init, _Integer}, {tol, _Real}},
    Module[{prev, el, ov=overlaps,swapEl=init},
      Prepend[
        Table[
          el=ov[[i]];
          If[el<-tol, swapEl=-swapEl];
          swapEl,
          {i, Length@ov}
          ],
        init
        ]
      ](*,
		CompilationTarget\[Rule]"C"*)
    ];


(* ::Subsubsubsection::Closed:: *)
(*rephaseWfns*)



rephaseWfns[s_, wfns_]:=
  WavefunctionsObject[
    {
      wfns["Energies"], 
      Map[Scale[#, s]&, wfns["Wavefunctions"]]
      },
    wfns["Grid"]
    ]


(* ::Subsubsubsection::Closed:: *)
(*getPhaseCorrection*)



getPhaseCorrection//Clear
getPhaseCorrection[wfs_List, 
  grid_,
  state:{_Integer?IntegerQ}:{2},
  basePhase:1|-1:1,
  rephase:True|False:False,
  defaultOrder:First|Last:First
  ]:=
  Module[
    {
      pos,
      gridPoints=grid["Points"],
      cleanGrid,
      cleanGridSorted,
      gridReordering,
      gridPositions,
      reorderedWfs,
      rephasedWavefunctions,
      fullWfs,
      overlaps,
      phases,
      orderComplement,
      phaseVector,
      newWfns,
      rephasingData
      },
    pos=Select[IntegerQ[#]&&#>0&]@Flatten@Position[wfs, _WavefunctionsObject, {1}];
    cleanGrid=Round[grid[[pos]].RotationMatrix[\[Pi]/4], .001];
    rephasingData=
      Table[
        cleanGridSorted=
          MapIndexed[If[EvenQ[#2[[1]]], Reverse, Identity]@#&]@
            SortBy[
              SortBy[#, sorting[[1]]]&/@GatherBy[cleanGrid, -#[[sorting[[2]]]]&], 
              -#[[1, -1]]&
              ];
        gridReordering=
          Flatten@
            Lookup[PositionIndex[cleanGrid], Flatten[cleanGridSorted, 1]
              ];
        gridPositions=pos[[gridReordering]];
        reorderedWfs=wfs[[gridPositions]];
        fullWfs=
          WavefunctionsObject[
            Flatten/@
            Transpose[
              {#["Energies"], #["Wavefunctions"][[state]]}&/@
              reorderedWfs
              ],
            reorderedWfs[[1]]["Grid"]
            ];
        overlaps=Developer`ToPackedArray[fullWfs@"Overlaps"[fullWfs]];
        phases=rephaseThingies[Diagonal[overlaps, 1], basePhase, 0];
        orderComplement=Complement[Range[Length@wfs], gridPositions];
        phaseVector=
          Join[phases, ConstantArray[$Failed, Length@orderComplement]][[
            Ordering@Join[gridPositions, orderComplement]
            ]];
        {
          gridReordering,
          phaseVector
          },
        {sorting, {{First, 2}, {Last, 1}}}
        ];
    If[rephasingData[[1, 2]] =!= rephasingData[[2, 2]],
      Print["Rephasing disagreement by sampling direction. Be careful."]
      ];
    {
      gridReordering,
      phaseVector
      } = 
      If[defaultOrder===First,
        rephasingData[[2]],
        rephasingData[[1]]
        ];
    If[rephase,
      newWfns=
        MapThread[
          If[#===$Failed,
            #,
            rephaseWfns[#, #2] 
            ]&,
          {
            phaseVector,
            wfs
            }
          ],
      newWfns=None
      ];
    <|
      "Wavefunctions"->newWfns,
      "PhaseVector"->phaseVector,
      "Positions"->pos,
      "Ordering"->gridPositions,
      "Phases"->phases
      |>
    ];


(* ::Subsubsubsection::Closed:: *)
(*getPhaseCorrection*)



getPhaseCorrection[wfs_List, 
  grid_,
  states:{_Integer?IntegerQ, __Integer?IntegerQ},
   basePhases:1|-1|{(1|-1)..}:1,
  rephase:True|False:True
  ]:=
  Module[{wfSets, rephasing, newWfns},
    wfSets=Table[If[#===$Failed, #, #[[{state}]]]&/@wfs, {state, states}];
    rephasing=
      MapThread[
        getPhaseCorrection[#, grid, {1}, #2, False]&, 
        {
          wfSets,
          Flatten[ConstantArray[basePhases, Length@wfSets]][[;;Length@wfSets]]
          } 
        ];
    If[rephase,
      newWfns=
        MapThread[
          If[#===$Failed, #, Join[##]]&,
          MapThread[
            MapThread[
              If[#===$Failed,
                #,
                rephaseWfns[#, #2] 
                ]&,
              {
                #["PhaseVector"],
                #2
                }
              ]&,
            {rephasing, wfSets}
            ]
          ],
      newWfns=None
      ];
    <|
      "Wavefunctions"->newWfns,
      "Rephasings"->rephasing
      |>
    ]


(* ::Subsubsubsection::Closed:: *)
(*getVectorPhaseCorrection*)



getVectorPhaseCorrection//Clear
getVectorPhaseCorrection[values_List, 
  grid_, 
  basePhase:1|-1:1,
  rephase:True|False:True,
  tol:_Real:.001
  ]:=
  Module[
    {
      pos,
      gridPoints=grid["Points"],
      cleanGrid,
      cleanGridSorted,
      gridReordering,
      gridPositions,
      ratios,
      reorderedVals,
      phases,
      orderComplement,
      phaseVector,
      newValues
      },
    pos=Flatten@Position[values, _?NumericQ, {1}];
    cleanGrid=Round[grid[[pos]].RotationMatrix[\[Pi]/4], .001];
    cleanGridSorted=
      MapIndexed[If[EvenQ[#2[[1]]], Reverse, Identity]@#&]@
        SortBy[
          SortBy[#, First]&/@GatherBy[cleanGrid, -#[[-1]]&], 
          -#[[1, -1]]&
          ];
    gridReordering=
      Flatten@
        Lookup[PositionIndex[cleanGrid], Flatten[cleanGridSorted, 1]
          ];
    gridPositions=pos[[gridReordering]];
    reorderedVals=values[[gridPositions]];
    ratios=MovingMap[If[#[[2]]!=0, Divide@@#, 0.]&, reorderedVals(*Differences[reorderedVals]*), 1];
    (*AppendTo[ratios, ratios[[-1]]]; *)
    phases=rephaseThingies[ratios, basePhase, tol];
    orderComplement=Complement[Range[Length@values], gridPositions];
    phaseVector=
      Join[phases, ConstantArray[$Failed, Length@orderComplement]][[
        Ordering@Join[gridPositions, orderComplement]
        ]];
    If[rephase,
      newValues=
        values*Replace[phaseVector, $Failed->1, 1],
      newValues=None
      ];
    <|
      "Values"->newValues,
      "PhaseVector"->phaseVector,
      "Positions"->pos,
      "Ordering"->gridPositions,
      "Phases"->phases
      |>
    ]


(* ::Subsubsection::Closed:: *)
(*SCF*)



(* ::Subsubsubsection::Closed:: *)
(*scfGrid*)



scfGrid[scfDvr_, basisSize_]:=
  scfGrid[scfDvr, basisSize]=
    scfDvr["Grid",
      "Points"->{basisSize, basisSize},
      "PotentialOptimize"->False
      ];


(* ::Subsubsubsection::Closed:: *)
(*scfWavefunction*)



scfWavefunction//Clear
scfWavefunction[
  scf1DDVR_,
  scfGrid_,
  pot_CompiledFunction,
  states:{{_Integer, _Integer}..},
  n:_Integer|Automatic:Automatic
  ]:=
  WavefunctionsObject[
    "SCF",
    scf1DDVR,
    GridFunctionObject[
      scfGrid,
      pot@scfGrid["Points"]
      ],
    "StateVectors"->states,
    "MaxIterations"->n
    ];


scfWavefunction[
  scf1DDVR_,
  scfGrid_,
  potentialGenerator_,
  {a_, s_},
  states:{{_Integer, _Integer}..},
  n:_Integer|Automatic:Automatic
  ]:=
  Module[{pot=potentialGenerator[{a, s}]},
    If[pot===$Failed,
      $Failed,
      scfWavefunction[
        scf1DDVR,
        scfGrid,
        pot,
        states,
        n
        ]
      ]
    ];


(* ::Subsubsubsection::Closed:: *)
(*scfCoeffData*)



scfCoeffData//Clear
scfCoeffData[
  scf1DDVR_,
  scf2DDVR_,
  scfGrid_,
  potentialGenerator_,
  states_,
  {a_, s_},
  basisSize_
  ]:=
  Module[
    {
      pot=potentialGenerator[{a, s}],
      wfs,
      wfs2D,
      coeffs,
      expand
      },
    If[pot===$Failed,
      $Failed,
      wfs=
        scfWavefunction[
          scf1DDVR,
          scfGrid,
          pot,
          states
          ];
      wfs2D=
        scf2DDVR[
          "Wavefunctions",
          "Points"->{basisSize, basisSize},
          "PotentialOptimize"->False,
          "PotentialFunction"->pot,
          "NumberOfWavefunctions"->Length@states,
          "PreadjustHamiltonian"->False,
          "ValidateHamiltonian"->False
          ];
      <|
        "SCFWavefunctions"->wfs, 
        "DVRWavefunctions"->wfs2D
        |>
      ]
    ]


(* ::Subsubsection::Closed:: *)
(*Overlaps*)



(* ::Subsubsubsection::Closed:: *)
(*getSCFOverlapMatrix*)



(* ::Subsubsubsubsection::Closed:: *)
(*Old*)



(*getSCFOverlapMatrix[scfWavefunctions_, dvrWavefunctions_, states_, scalings_]:=
	Module[
		{
			fleng,
			overlapStates=states,
			scalingThings=scalings,
			blerp,
			baseWfnsSCF,
			baseWfnsDVR,
			expansionCoeffs,
			blerpDVR,
			coeffs,
			overlaps,
			goodPlace,
			goodPos,
			goodPairs,
			goodSparseOneQuantum
			},
		If[Length@overlapStates!=Length@scalingThings, Throw@"I'm sad"];
		fleng=Length[scfWavefunctions];
		blerp=Select[scfWavefunctions, #=!=$Failed&];
		blerpDVR=Select[dvrWavefunctions, #=!=$Failed&];
		baseWfnsSCF=
			Table[Join@@Map[#[[{n}]]&, blerp], {n, overlapStates}];
		baseWfnsDVR=
			Table[Join@@Map[#[[{n}]]&, blerpDVR], {n, overlapStates}];
		coeffs=
			Apply[
				Join,
				scalingThings*
				Table[
					Transpose@
						Table[
							Developer`ToPackedArray[Diagonal[dvrWfs@"Overlaps"[scfWfs]]],
							{scfWfs, baseWfnsSCF}
							],
					{dvrWfs, baseWfnsDVR}
					]
				];
		overlaps=coeffs.Transpose[coeffs];
		{
			overlaps,
			goodPlace=Pick[Range[fleng], #=!=$Failed&/@scfWavefunctions];
			goodPos=Join@@Map[#+goodPlace&, Range[0, Length[overlapStates]-1]*fleng];
			goodPairs=Developer`ToPackedArray@Tuples[goodPos, 2];
			SparseArray[goodPairs\[Rule]Flatten@overlaps, Length[overlapStates]*fleng*{1,1} , 0.]
			}
		]*)


(* ::Subsubsubsubsection::Closed:: *)
(*New*)



getSCFOverlapMatrix//Clear
getSCFOverlapMatrix[
  scfWavefunctions_, dvrWavefunctions_, 
  states_, 
  scalings_, 
  grid_, extrapGrid_
  ]:=
  Module[
    {
      nstates, fleng, pickSpec, pickComp,
      gg, blerp, blerpDVR, 
      baseWfnsSCF, baseWfnsDVR, 
      coeffs, coeffLists,
      coeffInterps, newCoeffs
      },
    nstates = Length@states;
    pickSpec = Pick[Range[Length[scfWavefunctions]], #=!=$Failed&/@scfWavefunctions];
    pickComp = Pick[Range[Length[scfWavefunctions]], #===$Failed&/@scfWavefunctions];
    fleng = Length[pickSpec];
    debugPrint["Loading base coefficients"];
   blerp=scfWavefunctions[[pickSpec]];
    blerpDVR=dvrWavefunctions[[pickSpec]];
    gg = Join@@ConstantArray[grid[[pickSpec]], nstates];
    baseWfnsSCF=
      Table[Join@@Map[#[[{n}]]&, blerp], {n, states}];
    baseWfnsDVR=
      Table[Join@@Map[#[[{n}]]&, blerpDVR], {n, states}];
    coeffs=
      Apply[
        Join,
        Table[
          Transpose@
            Table[
              Developer`ToPackedArray[Diagonal[dvrWfs@"Overlaps"[scfWfs]]],
              {scfWfs, baseWfnsSCF}
              ],
          {dvrWfs, baseWfnsDVR}
          ]
        ];
    coeffLists = Join[gg, coeffs[[All, {#}]], 2]&/@Range[nstates];
    debugPrint["Extrapolating coefficients"];
    coeffInterps = 
      Table[
        With[{
          f=
            extrapolatedFunction[
              Join[
                Join[grid[[pickComp]], ConstantArray[10^9, {Length@pickComp, 1}], 2],
                #[[1+(i-1)*fleng ;; i*fleng]]
                ],
              {5, 5},
              {#^Range[1]&, #^Range[1]&}
              ]
          },
          Join[
            f[[All, ;;2]], 
            List/@Clip[f[[All, 3]]],
            2
            ]//Interpolation
          ],
        {i, nstates}
        ]&/@coeffLists;
    coeffs = 
      Transpose[
        Table[
          Apply[
            Join,
            With[{interp=#},
              interp@@Transpose[extrapGrid]
              ]&/@interpList
            ],
          {interpList, coeffInterps}
          ]
        ];
    coeffs.Transpose[coeffs]
    ]


(* ::Subsubsection::Closed:: *)
(*Wavefunctions*)



(* ::Subsubsubsection::Closed:: *)
(*Kinetic Energy*)



coupledKineticEnergy//Clear;
coupledKineticEnergy[dvr_, grid_, overlapMat_, i___]:=
  Module[
    {
      lens=Length[{i}],
      woop,
      waap=dvr["KineticEnergy", "Points"->Dimensions[grid]],
      klap
      },
    woop=overlapMat;
    (*Echo[{Dimensions[grid], Dimensions[waap], Dimensions[woop]}];*)
    If[Length[woop]=!=lens*Length[waap],
      Throw[
        "Overlap matrix misdimensioned, `` overlaps, `` functions, `` points"~TemplateApply~{
          Dimensions[woop],
          lens*Dimensions[waap],
          Dimensions[grid]
        }
        ],
      klap=
        KroneckerProduct[ConstantArray[1, {lens, lens}], waap];
      SparseArray[woop*klap] (* this _must_ be a SparseArray to be manageable later *)
      ]
    ];


(* ::Subsubsubsection::Closed:: *)
(*Potential Energy*)



getPot[wfns_, i_]:=
  Join[
    Keys[wfns],
    Developer`ToPackedArray@Map[
      If[#===$Failed, {10.^9}, #["Energies"][[{i}]]]&,
      Values@wfns
      ],
    2
    ];


averagedPot[wnfs_, i_]:=
  Developer`ToPackedArray@Map[
    If[#===$Failed, {10.^9}, #["Energies"][[{i}]]]&,
    Values@wnfs
    ]


extrapolatedPotential[grid_, wfns_, i_]:=
  With[
    {
      interp=
        Interpolation[
          extrapolatedFunction[
            getPot[wfns, i],
            {0, 10^9.-1},
            {Scaled[1], Scaled[.2]},
            {#^Range[6]&, #^Range[1]&}
            ],
          {
            "ExtrapolationHandler"->{
              (10.^9&),
              "WarningMessage"->False
              }
            }
          ]
      },
    interp@@Transpose[grid]
    ]


coupledPot[grid_, wfns_, i___]:=
  SparseArray[
    Band[{1, 1}]->
      Developer`ToPackedArray@
        Apply[Join, Map[extrapolatedPotential[grid, wfns, #]&, {i}]]
    ];


(* ::Subsubsubsection::Closed:: *)
(*Grid*)



coupledGrid[grid_, i__]:=
  With[{g=grid@"Grid", l=Length[{i}]},
    CoordinateGridObject@
      Apply[
        Join,
        With[{m=ConstantArray[{2*#*Min[g], 0}, Dimensions[g][[;;2]]]},
          g-m
          ]&/@Range[0, l-1]
        ]
    ]


(* ::Subsubsubsection::Closed:: *)
(*getWavefunctions*)



getWavefunctions[wfns_, dvr_, overlaps_, grid_, states___]:=
  WavefunctionsObject[
    "Diagonalize",
    debugPrint["Making kinetic energy"];
    coupledKineticEnergy[dvr, grid, overlaps, states],
    debugPrint["Making potential energy"];
    coupledPot[grid["Points"], wfns, states],
    debugPrint["Making grid"];
    coupledGrid[grid, states],
    debugPrint["Diagonalizing"];
    "NumberOfWavefunctions"->100,
    "ArnoldiIterations"->10000,
    "PruningEnergy"->Scaled[.9],
    "ValidateHamiltonian"->False
    ];


(* ::Subsubsubsection::Closed:: *)
(*pullProjections*)



pullProjections[wfns_, grid_, states_]:=
  With[{g2=grid, g=Min[grid["Points"]], len = Dimensions[grid][[1]], couplings=states},
    MapThread[
      Function[
        WavefunctionsObject[
          {
            #["Energies"],
            GridFunctionObject[
              g2,
              #@"Values"
              ]&/@#["Wavefunctions"]
            },
          g2
          ]&@wfns[[All, #;;#2]]
        ],
      {
        1+Range[0, Length[couplings]-1]*len,
        Range[Length@couplings]*len
        }
      ]
    ]


(* ::Subsubsection::Closed:: *)
(*Spectra*)



(* ::Subsubsubsection::Closed:: *)
(*rebuildInterpolation*)



rebuildInterpolation[interp_]:=
  Interpolation[
    Join[
      Flatten[interp["Grid"], 3],
      List/@Flatten[interp["ValuesOnGrid"], 3],
      2
      ],
    {
      "ExtrapolationHandler"->{
          0.&,
          "WarningMessage"->False
          }
      }
    ]


(* ::Subsubsubsection::Closed:: *)
(*interpolatedDipoleSurface*)



interpolatedDipoleSurface[interp_, {a_, s_}]:=
  With[{R1=1/Sqrt[2.](a+s), R2=1/Sqrt[2.](s-a)},
    interp[Sequence@@Transpose[#], R1, R2]&
    ]


(* ::Subsubsubsection::Closed:: *)
(*getDipoleVecs*)



getDipoleVecs[wfns_, gps_, interp_]:=
  MapIndexed[
    With[{fg=gps},
      If[#=!=$Failed,
        Developer`ToPackedArray[interpolatedDipoleSurface[interp, #2[[1, 1]]]@fg],
        $Failed
        ]&
      ],
    (* This is just here for the keys and the $Failed *)
    wfns
    ]


(* ::Subsubsubsection::Closed:: *)
(*getTransitionMoments*)



getTransitionMoments[wfns_, dipoles_]:=
  MapThread[
    If[#=!=$Failed,
      #@"TransitionMoments"[
          {
            #2, 
            ConstantArray[0., Length[#2]], 
            ConstantArray[0., Length[#2]]
            },
          {1, 1;;10}
          ],
      $Failed
      ]&,
    {
      wfns,
      dipoles
      }
    ]


(* ::Subsubsubsection::Closed:: *)
(*getTransitionWavefunctions*)



getTransitionWavefunctions[projs_, gsData_]:=
  Map[
    WavefunctionsObject[
      {
        Prepend[#["Energies"], gsData[[1]]], 
        Prepend[#["Wavefunctions"], gsData[[2]]]
        }, 
      gsData[[2]]["Grid"]
      ]&,
    projs
    ]


(* ::Subsubsubsection::Closed:: *)
(*getIntensities*)



getIntensities[wfns_, states_, gridTms_]:=
  Module[
    {
      baseTmoms,
      tmomLists,
      tmGrid,
      tmInterps,
      tms,
      wfGrid
      },
    tmGrid = gridTms["Grid"];
    tmInterps =
      Table[
        Interpolation[
          Join[tmGrid, List/@tm[[i]], 2],
          "ExtrapolationHandler"->{0&, "WarningMessage"->False}
          ],
        {i, 3},
        {tm, gridTms[["Values", states]]}
        ];
    wfGrid = wfns["Grid"]@"Points";
    tms = Transpose[Through[#[wfGrid]]]&/@tmInterps;
    baseTmoms=
      With[{wf=#},
          wf@"TransitionMoments"[
              Transpose[#],
              {1, If[MemberQ[states, 1], 1, 2];;Length[wf]}
              ]&/@tms
          ]&/@wfns;
    tmomLists = MapIndexed[#[[#2[[1]], All, 1]]&, baseTmoms];
    Total[tmomLists]^2
    ]


(* ::Subsubsubsection::Closed:: *)
(*getFreqs*)



getFreqs[wfns_, gsData_]:=
  wfns["Energies"]-gsData[[1]]


(* ::Subsubsubsection::Closed:: *)
(*buildSpectra*)



buildSpectra[freqs_, ints_]:=
  Module[
    {
      transInts
      },
    transInts=
      MapThread[
        With[{mlen=Min[Length/@{#, #2}]},
          #[[;;mlen]]*#2[[;;mlen]]
          ]&,
        {
          freqs,
          ints
          }
        ];
    transInts=transInts/Max[transInts];
    MapThread[
      ChemSpectrum@Transpose[{#, #2}]&,
      {
        freqs,
        transInts
        }
      ]
    ]


End[];


EndPackage[];


