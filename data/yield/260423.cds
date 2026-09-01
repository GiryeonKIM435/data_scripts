UniTestConditionFlie,Ver1.0
Begin MSATCondition 
	保存日=2026/04/29
	測定機種=STC
	試験の種類=圧縮試験
	試料名称=
	試料形状=板
	ロードセル定格荷重=500N
	試験速度=20mm/min
	中間点伸度=0mm
	中間点荷重=0N
End
Begin UniTestTensileCond 
	Begin SampleInformation 
		Begin CommonSampleInformation 
			Begin SampleName 
				Name=試料名称
				Level=Normal
				Data=
			End
			Begin Inspector 
				Name=試験者名
				Level=Normal
				Data=
			End
		End
		Begin SampleDimensionInformation 
			Shape=Plate
			TestCount=100
			Begin SampleDimension1 
				Dimension=0.001
				Unit=1
				SelectUnit=2
			End
			Begin SampleDimension2 
				Dimension=0.001
				Unit=1
				SelectUnit=2
			End
			Begin SampleDimension3 
				Dimension=0.001
				Unit=1
				SelectUnit=2
			End
			Begin Mass 
				Mass=1
				Unit=4
				SelectUnit=1
			End
		End
	End
	Begin MachineCondition 
		Begin MachineName 
			Name=試験機名称
			Level=Normal
			Data=STC
		End
		Begin TestKind 
			Name=試験の種類
			Level=Normal
			Data=Compression
		End
		Begin TestKindMachine 
			Name=試験機の試験の種類
			Level=Normal
			Data=Normal
		End
		Begin LoadcellCondition 
			Begin FullRange 
				Name=ロードセル定格荷重
				Level=Normal
				Unit=6
				SelectUnit=2
				Data=500
			End
			Begin Output 
				Name=ロードセル定格出力
				Level=Normal
				Unit=32
				SelectUnit=1
				Data=1
			End
		End
		Begin InflectionChangePoint 
			Begin TestSpeed 
				Name=試験速度
				Level=Normal
				Unit=9
				SelectUnit=4
				Data=1.19999976000005
			End
			Begin SamplingInterval 
				Name=サンプリング間隔
				Level=Normal
				Unit=1
				SelectUnit=1
				Data=0.000001
			End
		End
		Begin SkippingCount 
			Name=サンプリング間引き数
			Level=Normal
			Data=0
		End
	End
	Begin AnalysisCondition 
		Begin PointDataInElong 
			Name=中間点
			Level=Normal
			Unit=1
			SelectUnit=2
			Data1=0
			Data2=0
			Data3=0
			Data4=0
			Data5=0
			Data6=0
			PhysicalUnit=Elong
		End
		Begin PointDataInLoad 
			Name=中間点
			Level=Normal
			Unit=6
			SelectUnit=2
			Data1=0
			Data2=0
			Data3=0
			Data4=0
			Data5=0
			Data6=0
			PhysicalUnit=Load
		End
		Begin ElongAnalysis 
			Begin GageLength 
				Name=標線間距離
				Level=Normal
				Data=0.01
			End
			Begin JowLength 
				Name=チャック間距離
				Level=Normal
				Unit=1
				SelectUnit=2
				Data=0.05
			End
			Begin OriginOfElong 
				Name=伸び原点
				Level=Normal
				Data=InitialLoadPoint
				Begin InitialLoadValue 
					Name=初荷重値
					Level=Normal
					Unit=6
					SelectUnit=2
					Data=0.3
					PhysicalUnit=Load
				End
			End
			Begin ElongAdjust 
				Name=ゆるみ補正
				Level=Normal
				Data=No
			End
		End
		Begin ElasticModulus 
			Name=弾性率解析
			Level=Normal
			Unit=6
			SelectUnit=2
			ElasticModulusCalcType=0
			ElasticModulusCalcRule=0
			Direction=Load
			E-Start=1
			Begin E-Start 
				Name=開始点
				Level=Normal
			End
			E-End=100
			Begin E-End 
				Name=終了点
				Level=Normal
			End
			Interval=5
			Begin Interval 
				Name=ピッチ
				Level=Normal
			End
			Begin Offset 
				Name=オフセット
				Level=Normal
				Unit=14
				SelectUnit=2
				Data1=0.001
				Data2=0.002
			End
		End
		Begin InvaidateAmplitudeLevel 
			Name=無効振幅レベル
			Level=Normal
			Unit=6
			SelectUnit=2
			Data=1
			PhysicalUnit=Load
		End
		Begin BreakPoint 
			Name=破断点計測
			Level=Normal
			Unit=6
			SelectUnit=2
			Data=0.5
			PhysicalUnit=Load
		End
		Begin StartPoint 
			Name=測定開始点
			Level=Normal
			Unit=1
			SelectUnit=2
			StartPointKind=InitialLoad
			Data=1
		End
		Begin EndPoint 
			Name=測定終了点
			Level=Normal
			Unit=1
			SelectUnit=2
			EndPointKind=BreakPoint
			Data=1
		End
	End
	Begin TableCondition 
		Begin OutputItem 1 
			Name=最大点
			Unit=6
			SelectUnit=2
			AnalysisItem=Max
			PhysicalUnit=Load
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=0.999999
				LowerLimit=0.0000000001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 2 
			Name=最大点
			Unit=14
			SelectUnit=2
			AnalysisItem=Max
			PhysicalUnit=Strain
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=0.00999999
				LowerLimit=0.000000000001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 3 
			Name=中間伸度点
			Unit=8
			SelectUnit=3
			AnalysisItem=PointDataInElong1
			PhysicalUnit=Stress
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 4 
			Name=中間荷重点
			Unit=14
			SelectUnit=2
			AnalysisItem=PointDataInLoad1
			PhysicalUnit=Strain
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 5 
			Name=破断点
			Unit=8
			SelectUnit=3
			AnalysisItem=BreakPoint
			PhysicalUnit=Stress
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=99999900000000
				LowerLimit=10000
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 6 
			Name=破断点
			Unit=14
			SelectUnit=2
			AnalysisItem=BreakPoint
			PhysicalUnit=Strain
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 7 
			Name=第一極大点
			Unit=6
			SelectUnit=2
			AnalysisItem=FirstPeak
			PhysicalUnit=Load
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 8 
			Name=極大点
			Unit=6
			SelectUnit=2
			AnalysisItem=Peak
			PhysicalUnit=Load
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=0.999999
				LowerLimit=0.0000000001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Big1
		End
		Begin OutputItem 9 
			Name=極小点
			Unit=6
			SelectUnit=2
			AnalysisItem=Valley
			PhysicalUnit=Load
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=0.999999
				LowerLimit=0.0000000001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Big1
		End
		Begin OutputItem 10 
			Name=積分平均
			Unit=6
			SelectUnit=2
			AnalysisItem=IntegralAve
			PhysicalUnit=Load
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 11 
			Name=任意計算式
			Unit=0
			SelectUnit=0
			AnalysisItem=Fomula1
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 12 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 13 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 14 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 15 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 16 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 17 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 18 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 19 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin OutputItem 20 
			Name=
			Unit=0
			SelectUnit=0
			AnalysisItem=Null
			PhysicalUnit=Null
			Format=AUTO
			Rounding=Round
			Fomula=
			FomulaUnit=
			Begin AutoCansel 
				AutoCanselUsed=No
				UpperLimit=999999
				LowerLimit=0.0001
			End
			EnableEdit=True
			DataType=0
			MaxMinSelect=Null
		End
		Begin StatisticalOutput 1
			StatisticalItem=Average
			Name=平均
			Rounding=BeforeRounding
		End
		Begin StatisticalOutput 2
			StatisticalItem=Maximun
			Name=最大
			Rounding=BeforeRounding
		End
		Begin StatisticalOutput 3
			StatisticalItem=Minimun
			Name=最小
			Rounding=BeforeRounding
		End
		Begin StatisticalOutput 4
			StatisticalItem=Range
			Name=偏差(r)
			Rounding=BeforeRounding
		End
		Begin StatisticalOutput 5
			StatisticalItem=StandardDeviation(n-1)
			Name=標準偏差(n-1)
			Rounding=BeforeRounding
		End
		Begin StatisticalOutput 6
			StatisticalItem=Null
			Name=
			Rounding=BeforeRounding
		End
	End
	Begin GraphCondition 
		SSCurveTrace=0
		SSCurveFlag=Off
		Inching=Single
		InchingInterval=0.01
		BackColor=C0C0C0
		CompleteCurveColor=1
		AnalysisDrawMode=NewOnly
		Line1Style=SolidLine
		Line2Style=SolidLine
		AfterBreakPointView=1
		MaxPointPassMin=0
		MaxPointPassMax=1
		Begin XAxis 
			AutoRange=On
			PhysicalUnit=Time
			RangeMax=0.01
			RangeMin=0
			Unit=29
			SelectUnit=3
		End
		Begin YAxis 
			AutoRange=On
			PhysicalUnit=Load
			RangeMax=10
			RangeMin=0
			Unit=6
			SelectUnit=2
		End
		Begin Color 
			Trace=FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF,FF00FF,FFFFFF,0,FF0000,FFFF00,FF00,FFFF,FF
			Flag=On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On,On
		End
		Begin AnalysisPointColor 
			Trace=FF0000,800080,FF,FF00,FF00FF,FF,FF0000,FF80FF,FFFF,FF00,FF00
			Flag=On,On,Off,Off,Off,Off,Off,Off,Off,Off,On
		End
	End
	Begin Monitor 
		Begin Loadcell 
			DisplayMode=On
			PhysicalUnit=Load
			Unit=6
			SelectUnit=2
		End
		Begin Extension 
			DisplayMode=On
			PhysicalUnit=Elong
			Unit=1
			SelectUnit=2
		End
		Begin TestCount 
			DisplayMode=On
		End
		Begin MoveAverage 
			Begin LoadDispMoveAveCount 
				Name=荷重表示移動平均回数
				Level=Normal
				Data=1
			End
			Begin LoadDispDecimalpoint 
				Name=荷重表示小数点以下桁数
				Level=Normal
				Data=3
			End
			Begin ElongDispMoveAveCount 
				Name=変位表示移動平均回数
				Level=Normal
				Data=1
			End
			Begin ElongDispDecimalpoint 
				Name=変位表示小数点以下桁数
				Level=Normal
				Data=2
			End
		End
	End
	Begin RTE 
		Begin RTELoadCelllPower 
			Name=ロードセル
			Level=Normal
			LoadCellPullPower=True
			LoadCellCompPower=False
		End
		Begin RTETestDirection 
			Name=試験方向
			Level=Normal
			TestDirectionUp=False
			TestDirectionDown=True
		End
	End
	Begin RTEMachineConditionDetail 
		Begin RTELimitAct 
			LimitActOff=True
			LimitActStop=False
			LimitActReturn=False
			Begin LimitLoad 
				Data=500
				Unit=6
				SelectUnit=2
			End
			Begin LimitExt 
				Data=0.2
				Unit=1
				SelectUnit=2
			End
		End
		Begin RTEBreakAct 
			BreakActOff=False
			BreakActStop=False
			BreakActReturn=True
			Begin BreakInitLoad 
				Data=0.001
				Unit=6
				SelectUnit=1
			End
			BreakBreakSense=2
			BreakDropSense=3
		End
		Begin RTECycle 
			CycleMode=Load
			CycleCount=1
			CycleLimit=5
			UpperWaitTime=15
			LowerWaitTime=3
		End
		Begin RTETraverseSpeed 
			TraverseSpeed=300
			ReturnSpeed=300
		End
	End
End
