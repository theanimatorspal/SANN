require "jkrgui.all"
local normal_color = Theme.Colors.Button.Normal * 8
local hover_color = Theme.Colors.Button.Hover * 1.4
local large_font = Com.GetFont("font", "large")

Jkr.GLSL["SimulatedAnnealingCircleGraphCanvas"] = CanvasHeader .. [[
	vec2 center = vec2(0, 0);
	vec2 hw = vec2(0.8, 0.8);
	float radius = hw.x;

	float color = distance(xy_cartesian, center) - radius;
	vec4 old_color = imageLoad(storageImage, to_draw_at);
	vec4 final_color = vec4(pure_color.x * color, pure_color.y * color, pure_color.z * color, pure_color.w * color);
	final_color = mix(final_color, old_color, color);
	final_color = mix(pure_color, final_color, color);
	final_color.a = smoothstep(0.95, 1, final_color.a);

    final_color = mix(old_color, final_color, final_color.a);

    imageStore(storageImage, to_draw_at, final_color);
]]

Jkr.GLSL["SimulatedAnnealingCircleGraphCanvas"] = CanvasHeader .. [[
	vec2 center = vec2(0, 0);
	vec2 hw = vec2(0.8, 0.8);
	float radius = hw.x;

	float color = distance(xy_cartesian, center) - radius;
	vec4 old_color = imageLoad(storageImage, to_draw_at);
	vec4 final_color = vec4(pure_color.x * color, pure_color.y * color, pure_color.z * color, pure_color.w * color);
	final_color = mix(final_color, old_color, color);
	final_color = mix(pure_color, final_color, color);
	final_color.a = smoothstep(0.95, 1, final_color.a);

    final_color = mix(old_color, final_color, final_color.a);

    imageStore(storageImage, to_draw_at, final_color);
]]

SN.Graphics = {}

SN.Graphics.CircularGraph = {
    mCanvas = nil,
    mPosition_3f = nil,
    mDimension_3f = nil,
    mLines = nil,
    New = function(self, inPosition_3f, inDimension_3f, inLineCount)
        local Obj = {}
        setmetatable(Obj, self)
        self.__index = self
        Obj.mCanvas = Com.Canvas:New(inPosition_3f, inDimension_3f)
        Com.Canvas.AddPainterBrush(Obj.mCanvas, Com.GetCanvasPainter("Clear", false))
        Com.Canvas.AddPainterBrush(Obj.mCanvas, Com.GetCanvasPainter("SimulatedAnnealingCircleGraph", false))
        Com.Canvas.MakeCanvasImage(Obj.mCanvas, inDimension_3f.x, inDimension_3f.y)

        Com.NewSingleTimeDispatch(function()
            Obj.mCanvas.CurrentBrushId = 1
            Com.Canvas.Bind(Obj.mCanvas)
            Com.Canvas.Paint(Obj.mCanvas, vec4(0, 0, inDimension_3f.x, inDimension_3f.y), vec4(1, 1, 1, 1),
                vec4(1.2, 0, 0, 1), inDimension_3f.x, inDimension_3f.y, 1)
        end)

        Obj.mLineCount = 2000
        if inLineCount then
            Obj.mLineCount = inLineCount
        end
        Obj.mLines = {}

        for i = 1, Obj.mLineCount, 1 do
            Com.NewComponent()
            ComTable[com_i] = Jkr.Components.Static.LineObject:New(vec3(0, 0, 1), vec3(0, 0, 1))
            Obj.mLines[#Obj.mLines + 1] = com_i
        end
        Obj.mCurrentLineId = 1

        Obj.mPosition_3f = inPosition_3f
        Obj.mDimension_3f = inDimension_3f
        return Obj
    end,
    Update = function(self, inPosition_3f, inDimension_3f)
        self.mCanvas:Update(inPosition_3f, inDimension_3f)
    end,
    PlotAt = function(self, inX, inY, inW, inH, inColor_4f, inBrushId, inSimultaneous)
        if inSimultaneous then
            Com.NewSimulataneousDispatch()
        end
        Com.NewSimultaneousSingleTimeDispatch(function()
            self.mCanvas.CurrentBrushId = inBrushId
            Com.Canvas.Bind(self.mCanvas)
            Com.Canvas.Paint(self.mCanvas, vec4(inX, inY, inW, inH), inColor_4f, vec4(1.2, 0, 0, 1), inW, inH, 1)
        end)
    end,
    Clear = function(self, inColor_4f)
        Com.NewSimultaneousSingleTimeDispatch(function()
            self.mCanvas.CurrentBrushId = 1
            Com.Canvas.Bind(self.mCanvas)
            Com.Canvas.Paint(self.mCanvas, vec4(0, 0, self.mDimension_3f.x, self.mDimension_3f.y), inColor_4f,
                vec4(1.2, 0, 0, 1), self.mDimension_3f.x, self.mDimension_3f.y, 1)
        end)

        for i = 1, #self.mLines, 1 do
            ComTable[self.mLines[i]]:Update(vec3(0), vec3(0))
        end
        self.mCurrentLineId = 1
    end,
    UpdateGraphLine = function(self, inPosition1_3f, inPosition2_3f, inColor_4f)
        local id = self.mLines[self.mCurrentLineId]
        ComTable[id]:Update(inPosition1_3f, inPosition2_3f)
        if inColor_4f then
            ComTable[id]:SetColor(inColor_4f)
        end
        self.mCurrentLineId = self.mCurrentLineId + 1
    end,
    ResetLines = function(self)
        self.mCurrentLineId = 1
    end
}

SN.Graphics.DrawNeuralNetworkToGraph = function(inNeuralNetwork, inGraph, inSimultaneousDispatch)
    local topo = inNeuralNetwork.mTopology

    local max = 0
    for i = 1, #topo, 1 do
        if topo[i] > max then
            max = topo[i]
        end
    end

    local total_layers        = #topo
    local dis_between_layers  = inGraph.mDimension_3f.x / (total_layers) / 1.6
    local dis_between_neurons = inGraph.mDimension_3f.y / (max) / 1.3
    local middle_pos_y        = dis_between_neurons / 2 * (max - 1)
    local middle_pos_x        = dis_between_layers / 2 * (total_layers - 1)

    local radius              = dis_between_neurons / 1.05
    local G                   = SN.Graphics.CircularGraph
    local callbackNeuronsOnly = function(inPos_2f, inValue, inLayerNeuronCount)
        local xpos = middle_pos_x - total_layers / 2 * dis_between_layers + dis_between_layers * inPos_2f.x
        local ypos = middle_pos_y - inLayerNeuronCount / 2 * dis_between_neurons + inPos_2f.y * dis_between_neurons
        G.PlotAt(inGraph, xpos, ypos, radius, radius, vec4(-inValue, inValue / 2, 1, 1), 2, inSimultaneousDispatch)
    end
    inNeuralNetwork:PrintNeurons(callbackNeuronsOnly)

    local callbackWeightLines = function(leftLayer, inLeftNeuron, inLeftNeuronCount, inRightLayer, inRightNeuron,
                                         inRightNeuronCount, inWeightValue)
        local xposl = middle_pos_x - total_layers / 2 * dis_between_layers + dis_between_layers * leftLayer + radius / 2
        local yposl = middle_pos_y - inLeftNeuronCount / 2 * dis_between_neurons + inLeftNeuron * dis_between_neurons +
            radius / 2

        local xposr = middle_pos_x - total_layers / 2 * dis_between_layers + dis_between_layers * inRightLayer +
            radius / 2
        local yposr = middle_pos_y - inRightNeuronCount / 2 * dis_between_neurons + inRightNeuron * dis_between_neurons +
            radius / 2
        local color = vec4(-inWeightValue, inWeightValue, 0, math.abs(inWeightValue))
        SN.Graphics.CircularGraph.UpdateGraphLine(inGraph, vec3(xposl, yposl, 50), vec3(xposr, yposr, 50), color)
    end
    inNeuralNetwork:PrintLines(callbackWeightLines)
    inGraph:ResetLines()
end

SN.Graphics.CreateNumberPythagoreanTripletSolverWindow = function(CircularGraph)
    local Window = Com.MaterialWindow:New(vec3(WindowDimension.x - 400, 0, 50), vec3(400, WindowDimension.y, 1),
        vec2(400, 30), "Pythagorean Triplet", large_font)

    -- TODO event system optimization
    local RunButtonHLayout = Com.HLayout:New(0)
    local RunButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Run")
    local IterationsText = Com.TextButton:New(vec3(0), vec3(0), large_font, "Iterations")
    RunButtonHLayout:AddComponents({ RunButton, IterationsText }, { 0.5, 1 - 0.5 })

    local ClearButtonHLayout = Com.HLayout:New(0)
    local StopButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Stop")
    local ClearAllButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Clear")
    ClearButtonHLayout:AddComponents({ StopButton, ClearAllButton }, { 0.5, 1 - 0.5 })

    local TemperatureHLayout = Com.HLayout:New(0)
    local TemperatureText = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "Temperature")
    local TemperatureTextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "1000")
    TemperatureHLayout:AddComponents({ TemperatureText, TemperatureTextLineEdit }, { 0.5, 1 - 0.5 })

    local IterationCountHLayout = Com.HLayout:New(0)
    local IterationCountText = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "Iterations")
    local IterationCountTextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "500")
    IterationCountHLayout:AddComponents({ IterationCountText, IterationCountTextLineEdit }, { 0.5, 1 - 0.5 })

    local SumOfCountHLayout = Com.HLayout:New(0)
    local SumOfCountText = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "Third Number")
    local SumOfCountTextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "50")
    SumOfCountHLayout:AddComponents({ SumOfCountText, SumOfCountTextLineEdit }, { 0.5, 1 - 0.5 })

    local NumIHLayout = Com.HLayout:New(0)
    local NumIText = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "State:I")
    local NumITextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "3")
    NumIHLayout:AddComponents({ NumIText, NumITextLineEdit }, { 0.5, 1 - 0.5 })

    local NumJHLayout = Com.HLayout:New(0)
    local NumJText = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "State:J")
    local NumJTextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "4")
    NumJHLayout:AddComponents({ NumJText, NumJTextLineEdit }, { 0.5, 1 - 0.5 })

    local SizeFactorHLayout = Com.HLayout:New(0)
    local SizeFactorText = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "SizeFactor:")
    local SizeFactorTextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "0")
    SizeFactorHLayout:AddComponents({ SizeFactorText, SizeFactorTextLineEdit }, { 0.5, 1 - 0.5 })

    local StatusText = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "Status")
    local StatusText1 = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, " ")
    local StatusText2 = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, " ")
    local StatusText3 = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, " ")
    local StatusText4 = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, " ")
    local StatusText5 = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, " ")

    StatusText1:SetFillColor(vec4(0, 0, 0, 0))
    StatusText2:SetFillColor(vec4(0, 0, 0, 0))
    StatusText3:SetFillColor(vec4(0, 0, 0, 0))
    StatusText4:SetFillColor(vec4(0, 0, 0, 0))
    StatusText5:SetFillColor(vec4(0, 0, 0, 0))

    local HComponents = {
        RunButtonHLayout,
        ClearButtonHLayout,
        Com.HLayout:New(0),
        TemperatureHLayout,
        IterationCountHLayout,
        SumOfCountHLayout,
        Com.HLayout:New(0),
        NumIHLayout,
        NumJHLayout,
        SizeFactorHLayout,
        Com.HLayout:New(0),
        StatusText,
        StatusText1,
        StatusText2,
        StatusText3,
        StatusText4,
        StatusText5,
        Com.HLayout:New(0)
    }

    -- local HComponentsRatio = {0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 1 - (0.04 * (#HComponents - 1))}
    local HComponentsRatio = {}
    for i = 1, #HComponents, 1 do
        HComponentsRatio[i] = 0.04
    end
    HComponentsRatio[#HComponentsRatio] = 1 - (0.04 * (#HComponents - 1))



    local VLayout = Com.VLayout:New(0)
    VLayout:AddComponents(HComponents, HComponentsRatio)
    Window:SetCentralComponent(VLayout)

    -- Note, not a good name, not a good heuristic
    local IterationsMax__ = 1000
    local SizeFactor__ = 3
    local gcg = SN.Graphics.CircularGraph
    local CallbackFunction = function(inS, inT, inK, inS_new)
        local Energy = SN.E(inS)
        local Temperature = inT / SN.InitialTemperature
        IterationsText:Update(IterationsText.mPosition_3f, IterationsText.mDimension_3f,
            tostring(Int(IterationsMax__ - inK)))
        StatusText1:Update(StatusText1.mPosition_3f, StatusText1.mDimension_3f,
            string.format("Accepted(%d, %d)", inS.i, inS.j))
        StatusText2:Update(StatusText2.mPosition_3f, StatusText2.mDimension_3f,
            string.format("New(%d, %d)", inS_new.i, inS_new.j))
        StatusText3:Update(StatusText3.mPosition_3f, StatusText3.mDimension_3f, string.format("(T%f, E%f)", inT, Energy))
        local rand_color = vec4(1 - Temperature, math.random(), math.random(), 1)
        local visualEnergy = Energy
        if SizeFactor__ == 0 then
            visualEnergy = 200
        else
            visualEnergy = Energy * SizeFactor__
        end

        if visualEnergy >= 10000 then
            visualEnergy = 100
        end

        gcg.PlotAt(CircularGraph, inS.i, inS.j, visualEnergy, visualEnergy,
            rand_color, 2)
    end
    RunButton:SetFunctions(
        function()
            RunButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            RunButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            local Iterations = tonumber(IterationCountTextLineEdit:GetText())
            local SumTo = tonumber(SumOfCountTextLineEdit:GetText())
            local Temperature = tonumber(TemperatureTextLineEdit:GetText())
            local I = tonumber(NumITextLineEdit:GetText())
            local J = tonumber(NumJTextLineEdit:GetText())
            local SizeFactor = tonumber(SizeFactorTextLineEdit:GetText())
            if Iterations then
                IterationsMax__ = Iterations
            end
            if SizeFactor then
                SizeFactor__ = SizeFactor
            end

            Com.ClearSingleTimes()
            SN.Core.SetProblem_PythagoreanTriplet(Temperature, SumTo)
            SN.Solve(SN.State:New(I, J), Iterations, CallbackFunction)
        end
    )

    StopButton:SetFunctions(
        function()
            StopButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            StopButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            Com.ClearSingleTimes()
        end
    )

    ClearAllButton:SetFunctions(
        function()
            ClearAllButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            ClearAllButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            Com.ClearSingleTimes()
            SN.Graphics.CircularGraph.Clear(CircularGraph, vec4(1, 1, 1, 0))
        end
    )
    return Window
end

SN.Graphics.CreateNNVisualizerWindow = function(CircularGraph)
    local Window = Com.MaterialWindow:New(vec3(WindowDimension.x - 400, 0, 50), vec3(400, WindowDimension.y, 1),
        vec2(400, 30), "NN Visualize", Com.GetFont("font", "large"))

    local CreateButtonHLayout = Com.HLayout:New(0)
    local CreateButton = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "Create")
    CreateButtonHLayout:AddComponents({ CreateButton, Com.HLayout:New(0) }, { 0.5, 1 - 0.5 })

    local RunButtonHLayout = Com.HLayout:New(0)
    local RunButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Train")
    local ClearButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Clear")
    RunButtonHLayout:AddComponents({ RunButton, ClearButton }, { 0.5, 1 - 0.5 })

    local Layer1HLayout = Com.HLayout:New(0)
    local Layer1Text = Com.TextButton:New(vec3(200, 200, 1), vec3(300, 300, 1), large_font, "Layer1")
    local Layer1TextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "2")
    Layer1HLayout:AddComponents({ Layer1Text, Layer1TextLineEdit }, { 0.5, 1 - 0.5 })

    local Layer2HLayout = Com.HLayout:New(0)
    local Layer2Text = Com.TextButton:New(vec3(200, 200, 2), vec3(300, 300, 2), large_font, "Layer2")
    local Layer2TextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "3")
    Layer2HLayout:AddComponents({ Layer2Text, Layer2TextLineEdit }, { 0.5, 2 - 0.5 })

    local Layer3HLayout = Com.HLayout:New(0)
    local Layer3Text = Com.TextButton:New(vec3(300, 300, 3), vec3(300, 300, 3), large_font, "Layer3")
    local Layer3TextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "2")
    Layer3HLayout:AddComponents({ Layer3Text, Layer3TextLineEdit }, { 0.5, 3 - 0.5 })

    local Layer4HLayout = Com.HLayout:New(0)
    local Layer4Text = Com.TextButton:New(vec3(400, 400, 4), vec3(400, 400, 4), large_font, "Layer4")
    local Layer4TextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "1")
    Layer4HLayout:AddComponents({ Layer4Text, Layer4TextLineEdit }, { 0.5, 4 - 0.5 })

    local Input1HLayout = Com.HLayout:New(0)
    local Input1Text = Com.TextButton:New(vec3(400, 400, 4), vec3(400, 400, 4), large_font, "Input1")
    local Input1TextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "1")
    Input1HLayout:AddComponents({ Input1Text, Input1TextLineEdit }, { 0.5, 4 - 0.5 })

    local Input2HLayout = Com.HLayout:New(0)
    local Input2Text = Com.TextButton:New(vec3(400, 400, 4), vec3(400, 400, 4), large_font, "Input2")
    local Input2TextLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "0")
    Input2HLayout:AddComponents({ Input2Text, Input2TextLineEdit }, { 0.5, 4 - 0.5 })

    local PropForwardButtonHLayout = Com.HLayout:New(0)
    local PropForwardButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Propagate Forward")
    PropForwardButtonHLayout:AddComponents({ PropForwardButton, Com.HLayout:New(0) }, { 0.5, 1 - 0.5 })

    local CreateNetworkByPictureHLayout = Com.HLayout:New(0)
    local CreateNetworkByPictureButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Create Net by Pic")
    CreateNetworkByPictureHLayout:AddComponents({ CreateNetworkByPictureButton, Com.HLayout:New(0) }, { 0.5, 1 - 0.5 })

    local PropagateForwardPictureHLayout = Com.HLayout:New(0)
    local PropagateForwardPictureButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Propagate Forward")
    PropagateForwardPictureHLayout:AddComponents({ PropagateForwardPictureButton, Com.HLayout:New(0) }, { 0.5, 1 - 0.5 })

    local PropagateBackwardPictureHLayout = Com.HLayout:New(0)
    local PropagateBackwardPictureButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Propagate Backward")
    PropagateBackwardPictureHLayout:AddComponents({ PropagateBackwardPictureButton, Com.HLayout:New(0) },
        { 0.5, 1 - 0.5 })

    local UpdatePicHLayout = Com.HLayout:New(0)
    local UpdatePicButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Update")
    UpdatePicHLayout:AddComponents({ UpdatePicButton, Com.HLayout:New(0) }, { 0.5, 1 - 0.5 })

    local TrainInverseHLayout = Com.HLayout:New(0)
    local TrainInverseButton = Com.TextButton:New(vec3(0), vec3(0), large_font, "Train Inverse")
    TrainInverseHLayout:AddComponents({ TrainInverseButton, Com.HLayout:New(0) }, { 0.5, 1 - 0.5 })

    local TrainingCountHLayout = Com.HLayout:New(0)
    local TrainingCountText = Com.TextButton:New(vec3(400, 400, 4), vec3(400, 400, 4), large_font, "Count")
    local TrainingCountLineEdit = Com.MaterialLineEdit:New(vec3(0), vec3(0), large_font, "1")
    TrainingCountHLayout:AddComponents({ TrainingCountText, TrainingCountLineEdit }, { 0.5, 4 - 0.5 })

    local HComponents = {
        CreateButtonHLayout,
        RunButtonHLayout,
        Com.HLayout:New(0),
        Layer1HLayout,
        Layer2HLayout,
        Layer3HLayout,
        Layer4HLayout,
        Com.HLayout:New(0),
        Input1HLayout,
        Input2HLayout,
        PropForwardButton,
        Com.HLayout:New(0),
        CreateNetworkByPictureHLayout,
        PropagateForwardPictureHLayout,
        PropagateBackwardPictureHLayout,
        UpdatePicHLayout,
        Com.HLayout:New(0),
        TrainInverseHLayout,
        TrainingCountHLayout,
        Com.HLayout:New(0)

    }

    local HComponentsRatio = {}
    for i = 1, #HComponents, 1 do
        HComponentsRatio[i] = 0.04
    end
    HComponentsRatio[#HComponentsRatio] = 1 - (0.04 * (#HComponents - 1))

    local VLayout = Com.VLayout:New(0)
    VLayout:AddComponents(HComponents, HComponentsRatio)
    Window:SetCentralComponent(VLayout)


    local mero_NN = {}
    local GetTopologyByTextFieldsLayer = function()
        local layer1_neurons = tonumber(Layer1TextLineEdit:GetText())
        local layer2_neurons = tonumber(Layer2TextLineEdit:GetText())
        local layer3_neurons = tonumber(Layer3TextLineEdit:GetText())
        local layer4_neurons = tonumber(Layer4TextLineEdit:GetText())
        return { layer1_neurons, layer2_neurons, layer3_neurons, layer4_neurons }
    end

    RunButton:SetFunctions(
        function()
            RunButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            RunButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            for i = 1, 50, 1 do
                Com.NewSimulataneousDispatch()
                Com.NewSimultaneousUpdate()
                Com.NewSimultaneousSingleTimeUpdate(
                    function()
                        mero_NN:Train(500)
                        SN.Graphics.DrawNeuralNetworkToGraph(mero_NN, CircularGraph)
                    end
                )
            end
        end
    )

    ClearButton:SetFunctions(
        function()
            ClearButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            ClearButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            Com.ClearSingleTimes()
            SN.Graphics.CircularGraph.Clear(CircularGraph, vec4(1, 1, 1, 0))
        end
    )


    PropForwardButton:SetFunctions(
        function()
            PropForwardButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            PropForwardButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            local input1 = tonumber(Input1TextLineEdit:GetText())
            local input2 = tonumber(Input2TextLineEdit:GetText())
            mero_NN:PropagateForward({ input1, input2 })
            SN.Graphics.DrawNeuralNetworkToGraph(mero_NN, CircularGraph)
        end
    )


    CreateButton:SetFunctions(
        function()
            CreateButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            CreateButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            mero_NN = NN.SimpleNN:New(GetTopologyByTextFieldsLayer())
            Com.ClearSingleTimes()
            SN.Graphics.CircularGraph.Clear(CircularGraph, vec4(1, 1, 1, 0))
            SN.Graphics.DrawNeuralNetworkToGraph(mero_NN, CircularGraph, true)
        end
    )

    CreateNetworkByPictureButton:SetFunctions(
        function()
            CreateNetworkByPictureButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            CreateNetworkByPictureButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color
            .w))
        end,
        function()
            local c = SN.Graphics.InputPictureCanvas
            local o = SN.Graphics.OutputPictureCanvas
            local topByLayer = GetTopologyByTextFieldsLayer()
            local topology = {}
            topology[#topology+1] = c.mXSize * c.mYSize
            for i = 1, #topByLayer, 1 do
               topology[#topology+1] = topByLayer[i]
            end
            topology[#topology+1] = o.mXSize * o.mYSize
            mero_NN = NN.SimpleNN:New(topology)
            Com.ClearSingleTimes()
            SN.Graphics.CircularGraph.Clear(CircularGraph, vec4(1, 1, 1, 0))
            SN.Graphics.DrawNeuralNetworkToGraph(mero_NN, CircularGraph, true)
        end
    )

    local propForward = function()
        local ImageF = Com.Canvas.GetVectorFloatSingleChannel(SN.Graphics.InputPictureCanvas)
        mero_NN:PropagateForwardVecFloat(ImageF)
        local Output = NN.SimpleNN.GetOutputFloatVec(mero_NN, #mero_NN.mTopology - 1)
        Com.NewSimultaneousSingleTimeDispatch(
            function()
                Com.Canvas.DrawClearFromFloatSingleChannel(SN.Graphics.OutputPictureCanvas, Output)
            end
        )
        SN.Graphics.DrawNeuralNetworkToGraph(mero_NN, CircularGraph, true)
    end
    local propBackward = function()
        local ImageF = Com.Canvas.GetVectorFloatSingleChannel(SN.Graphics.ExpectedOutputPictureCanvas)
        mero_NN:PropagateBackwardVecFloat(ImageF)
        -- local Output = NN.SimpleNN.GetOutputFloatVec(mero_NN, #mero_NN.mTopology - 1)
        -- Com.NewSimultaneousSingleTimeDispatch(
        --      function()
        --          Com.Canvas.DrawClearFromFloatSingleChannel(SN.Graphics.OutputPictureCanvas, Output)
        --      end
        -- )
        SN.Graphics.DrawNeuralNetworkToGraph(mero_NN, CircularGraph, true)
    end
    PropagateForwardPictureButton:SetFunctions(
        function()
            PropagateForwardPictureButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            PropagateForwardPictureButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z,
                normal_color.w))
        end,
        function()
            Com.NewSimultaneousSingleTimeUpdate(propForward)
        end
    )

    PropagateBackwardPictureButton:SetFunctions(
        function()
            PropagateBackwardPictureButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            PropagateBackwardPictureButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z,
                normal_color.w))
        end,
        function()
            Com.NewSimultaneousSingleTimeUpdate(propBackward)
        end
    )

    UpdatePicButton:SetFunctions(
        function()
            UpdatePicButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            UpdatePicButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            SN.Graphics.DrawNeuralNetworkToGraph(mero_NN, CircularGraph, true)
        end
    )

    local trainInverse = function()
        local i = SN.Graphics.InputPictureCanvas
        local eo = SN.Graphics.ExpectedOutputPictureCanvas
        local o = SN.Graphics.OutputPictureCanvas
        local InputOutputImageFloats = NN.ImageGetRandomInputInverseOutput(i.mXSize * i.mYSize, o.mXSize * o.mYSize)
        mero_NN:PropagateForwardVecFloat(InputOutputImageFloats[1])
        mero_NN:PropagateBackwardVecFloat(InputOutputImageFloats[2])
        local Output = NN.SimpleNN.GetOutputFloatVec(mero_NN, #mero_NN.mTopology - 1)


        Com.NewSimultaneousSingleTimeDispatch(
            function()
                Com.Canvas.DrawClearFromFloatSingleChannel(i, InputOutputImageFloats[1])
                Com.Canvas.DrawClearFromFloatSingleChannel(eo, InputOutputImageFloats[2])
                Com.Canvas.DrawClearFromFloatSingleChannel(o, Output)
            end
        )
        -- Com.NewSimultaneousSingleTimeUpdate(
        --     function()
        --         SN.Graphics.DrawNeuralNetworkToGraph(mero_NN, CircularGraph, true)
        --     end
        -- )
    end

    TrainInverseButton:SetFunctions(
        function()
            TrainInverseButton:SetFillColor(vec4(hover_color.x, hover_color.y, hover_color.z, hover_color.w))
        end,
        function()
            TrainInverseButton:SetFillColor(vec4(normal_color.x, normal_color.y, normal_color.z, normal_color.w))
        end,
        function()
            local Itrs = tonumber(TrainingCountLineEdit:GetText())
            for i = 1, Itrs, 1 do
                trainInverse()
            end
        end
    )
    return Window
end

SN.Graphics.CreateProblem3SolverWindow = function(inTable)
    local Window = Com.MaterialWindow:New(vec3(WindowDimension.x - 400, 0, 50), vec3(400, WindowDimension.y, 1),
        vec2(400, 30), "Problem 2", Com.GetFont("font", "large"))

    Window:SetCentralComponent(Com.VLayout:New(0))
    return Window
end

SN.Graphics.CreateProblemWindowsLayout = function(inTable)
    local problemWindows = Com.HLayout:New(0)
    problemWindows.mCurrentWindow = 1
    local Window1 = SN.Graphics.CreateNumberPythagoreanTripletSolverWindow(inTable[1])
    local Window2 = SN.Graphics.CreateNNVisualizerWindow(inTable[2])
    local Window3 = SN.Graphics.CreateProblem3SolverWindow(inTable[3])
    problemWindows.Update = function(self, inPosition_3f, inDimension_3f, inWindowNo, inInverseSpeed)
        tracy.ZoneBeginN("ProblemWindows Update")
        if inWindowNo then
            self.mCurrentWindow = inWindowNo
        end
        local newPos = vec3(inPosition_3f.x - (inDimension_3f.x) * (self.mCurrentWindow - 1), inPosition_3f.y,
            inPosition_3f.z)
        local newDimen = vec3(inDimension_3f.x * 3, inDimension_3f.y, inDimension_3f.z)

        local invspeed = 0.1
        if inInverseSpeed then
            invspeed = inInverseSpeed
        end

        if inWindowNo then
            local oldPos = vec3(inPosition_3f.x, inPosition_3f.y, inPosition_3f.z)
            local oldDimen = vec3(inDimension_3f.x, inDimension_3f.y, inDimension_3f.z)
            local from = { mPosition_3f = oldPos, mDimension_3f = oldDimen }
            local to = { mPosition_3f = newPos, mDimension_3f = newDimen }
            -- Com.AnimateSingleTimePosDimenCallback(from, to, invspeed,
            --     function(pos, dimen)
            --         Com.HLayout.Update(self, pos, dimen)
            --     end,
            --     function()
            --         self.mPosition_3f = inPosition_3f
            --         self.mDimension_3f = inDimension_3f
            --     end)
            Com.HLayout.Update(self, newPos, newDimen)
        else
            Com.HLayout.Update(self, newPos, newDimen)
        end

        self.mPosition_3f = inPosition_3f
        self.mDimension_3f = inDimension_3f
        tracy.ZoneEnd()
    end

    problemWindows:AddComponents({ Window1, Window2, Window3 }, { 1 / 3, 1 / 3, 1 / 3 })
    return problemWindows
end

local MakePictureCanvas = function(inX, inY)
    local Canvas = Com.Canvas:New(vec3(0), vec3(0))
    Com.Canvas.AddPainterBrush(Canvas, Com.GetCanvasPainter("Clear", false))
    Com.Canvas.MakeCanvasImage(Canvas, inX, inY)
    Com.NewSimulataneousDispatch()
    Com.NewSimultaneousSingleTimeDispatch(function()
        Canvas.CurrentBrushId = 1
        Com.Canvas.Bind(Canvas)
        Com.Canvas.Paint(Canvas, vec4(0, 0, inX, inY), vec4(1, 0, 0, 1), vec4(0), inX, inY, 1)
    end)
    Canvas.mXSize = inX
    Canvas.mYSize = inY
    return Canvas
end

SN.Graphics.InputPictureCanvas = {}
SN.Graphics.OutputPictureCanvas = {}
SN.Graphics.ExpectedOutputPictureCanvas = {}
SN.Graphics.MakePictureWindow = function()
    local PictureWindow = Com.MaterialWindow:New(vec3(WindowDimension.x - 600, 0, 80), vec3(200, 600, 80), vec2(200, 30),
        "PD",
        Com.GetFont("font", "large"))
    PictureWindow:Start()
    SN.Graphics.InputPictureCanvas = MakePictureCanvas(5, 5)
    SN.Graphics.OutputPictureCanvas = MakePictureCanvas(2, 2)
    SN.Graphics.ExpectedOutputPictureCanvas = MakePictureCanvas(2, 2)
    local VLayout = Com.VLayout:New(5)
    VLayout:AddComponents(
    { SN.Graphics.InputPictureCanvas, SN.Graphics.OutputPictureCanvas, SN.Graphics.ExpectedOutputPictureCanvas },
        { 1 / 3, 1 / 3, 1 / 3 })
    PictureWindow:SetCentralComponent(VLayout)
    PictureWindow:End()
    return PictureWindow
end

SN.Graphics.CreateGUI = function()
    LoadMaterialComponents(false)
    local Graph = SN.Graphics.CircularGraph:New(vec3(0), vec3(WindowDimension.x, WindowDimension.y, 1))
    Graph:Update(vec3(0, 0, 90), vec3(WindowDimension.x, WindowDimension.y, 1))
    local Window = Com.MaterialWindow:New(vec3(WindowDimension.x - 400, 0, 50), vec3(400, WindowDimension.y, 1),
        vec2(350, 30), "Simulated Annealing", Com.GetFont("font", "large"))
    -- TODO Error In Canvas NavBar if initialized here IDK Why
    local PictureWindow = {}
    Window:Start()
    local insideWindow = function()
        local area = Com.AreaObject:New(vec3(0), vec3(0))
        Com.AreaObject.SetFillColor(area, vec4(0.8, 0.8, 0.8, 0.5))
        local color_navbarind = vec4(1, 0.4, 0.8, 1)
        local color_tint = vec4(1, 0, 0, 0.01)

        local NavBarElem1 = Com.AreaButton:New(vec3(0), vec3(0))
        local NavBarElem2 = Com.AreaButton:New(vec3(0), vec3(0))
        local NavBarElem3 = Com.AreaButton:New(vec3(0), vec3(0))

        local NavBarDimension = vec3(WindowDimension.x, WindowDimension.y * 0.1, 1)
        local NavBarPosition = vec3(0, WindowDimension.y - NavBarDimension.y, 50)
        local NavBar = Com.NavigationBar:New(NavBarPosition, NavBarDimension, { NavBarElem1, NavBarElem2, NavBarElem3 },
            true)

        local ClearNavBarColor = function()
            NavBarElem1:TintColor(vec4(1))
            NavBarElem2:TintColor(vec4(1))
            NavBarElem3:TintColor(vec4(1))
        end
        ClearNavBarColor()


        local problemWindows = SN.Graphics.CreateProblemWindowsLayout({ Graph, Graph, Graph })

        Com.NavigationBar.Update(NavBar, NavBarPosition, NavBarDimension, 1)
        local vlayout = Com.VLayout:New(0)
        local stack = Com.StackLayout:New(0)
        vlayout:AddComponents({ NavBar, problemWindows }, { 0.05, 0.9 })
        stack:AddComponents({ area, vlayout })
        Window:SetCentralComponent(stack)

        NavBarElem1:SetFunctions(
            function() NavBarElem1:TintColor(color_tint) end,
            function() NavBarElem1:TintColor(vec4(1)) end,
            function()
                ClearNavBarColor()
                problemWindows:Update(problemWindows.mPosition_3f, problemWindows.mDimension_3f, 1, 0.2)
                Com.NavigationBar.Animate(NavBar, NavBar.mPosition_3f, NavBar.mDimension_3f, 1, 0.2)
            end)
        NavBarElem2:SetFunctions(
            function() NavBarElem2:TintColor(color_tint) end,
            function() NavBarElem2:TintColor(vec4(1)) end,
            function()
                ClearNavBarColor()
                problemWindows:Update(problemWindows.mPosition_3f, problemWindows.mDimension_3f, 2, 0.2)
                Com.NavigationBar.Animate(NavBar, NavBar.mPosition_3f, NavBar.mDimension_3f, 2, 0.2)
            end)
        NavBarElem3:SetFunctions(
            function() NavBarElem3:TintColor(color_tint) end,
            function() NavBarElem3:TintColor(vec4(1)) end,
            function()
                ClearNavBarColor()
                problemWindows:Update(problemWindows.mPosition_3f, problemWindows.mDimension_3f, 3, 0.2)
                Com.NavigationBar.Animate(NavBar, NavBar.mPosition_3f, NavBar.mDimension_3f, 3, 0.2)
            end)

        Com.NewSimultaneousSingleTimeDispatch(
            function()
                Com.NavigationBar.Dispatch(NavBar, color_navbarind)
            end
        )
    end
    insideWindow()
    Window:End()
    Window:Update(vec3(WindowDimension.x - 400, 0, 50), vec3(400, WindowDimension.y, 1))
    PictureWindow = SN.Graphics.MakePictureWindow()

    Com.NewEvent(
        function()
            if E.is_keypress_event() and E.is_key_pressed(Key.SDLK_SPACE) then
                Window:Update(vec3(WindowDimension.x - 400, 0, 50), vec3(400, WindowDimension.y, 1))
                PictureWindow:Update(vec3(WindowDimension.x - 600, 0, 80), vec3(200, 600, 80))
            end
        end
    )

    collectgarbage("collect")
end
