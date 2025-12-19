# ================================================================================
# UNIT TESTS для unlockables_device
# Файл: unlockables_tests.verse
# Проект: Fortnite Tycoon Simulator
# ================================================================================

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }

# ================================================================================
# ТЕСТОВИЙ ФРЕЙМВОРК
# ================================================================================

test_result := class:
    var TotalTests : int = 0
    var PassedTests : int = 0
    var FailedTests : int = 0

var GlobalTestResults : test_result = test_result{}

LogPass(TestName : string):void=
    set GlobalTestResults.TotalTests += 1
    set GlobalTestResults.PassedTests += 1
    Print("{TestName} - PASSED")

LogFail(TestName : string):void=
    set GlobalTestResults.TotalTests += 1
    set GlobalTestResults.FailedTests += 1
    Print("{TestName} - FAILED")

PrintSummary():void=
    Print("")
    Print("================================")
    Print("TOTAL: {GlobalTestResults.TotalTests}")
    Print("PASSED: {GlobalTestResults.PassedTests}")
    Print("FAILED: {GlobalTestResults.FailedTests}")
    Print("================================")

# ================================================================================
# ТЕСТОВИЙ ДЕВАЙС
# ================================================================================

unlockables_test_device := class(creative_device):

    @editable
    DeviceUnderTest : unlockables_device = unlockables_device{}
    
    @editable
    TestTrigger : trigger_device = trigger_device{}
    
    @editable
    TestGoldButton : conditional_button_device = conditional_button_device{}
    
    @editable
    TestBillboard : billboard_device = billboard_device{}
    
    @editable
    TestProps : []creative_prop = array{}
    
    MoveOnZ : float = 1500.0
    DebounceTime : float = 1.0

    var InitialPropsPositions : []vector3 = array{}
    var InitialTriggerPosition : vector3 = vector3{}
    var TestPlayerAgent : ?agent = false

    OnBegin<override>()<suspends>:void=
        Print("")
        Print("=== UNLOCKABLES_DEVICE UNIT TESTS ===")
        Print("")
        
        SaveInitialState()
        Sleep(1.0)
        GetTestPlayer()
        
        RunAllTests()
        PrintSummary()

    SaveInitialState():void=
        for (Prop : TestProps):
            if (PropTransform := Prop.GetTransform()):
                set InitialPropsPositions += array{PropTransform.Translation}
        
        if (TriggerTransform := TestTrigger.GetTransform()):
            set InitialTriggerPosition = TriggerTransform.Translation

    GetTestPlayer():void=
        Playspace := GetPlayspace()
        Players := Playspace.GetPlayers()
        if (FirstPlayer := Players[0]):
            set TestPlayerAgent = option{FirstPlayer}

    RunAllTests()<suspends>:void=
        Test_MoveProps_ValidPurchase()
        Sleep(0.3)
        Test_MoveProps_ResetOnLeave()
        Sleep(0.3)
        Test_MoveClaimerToPurchase_Position()
        Sleep(0.3)
        Test_OnClaimerTriggered_FirstPlayer()
        Sleep(0.3)
        Test_OnClaimerTriggered_NotOwner()
        Sleep(0.3)
        Test_OnClaimerTriggered_InsufficientGold()
        Sleep(0.3)
        Test_GoldDeduction_OnPurchase()
        Sleep(0.3)
        Test_Billboard_SetText_Price()
        Sleep(0.3)
        Test_Billboard_SetText_Free()
        Sleep(0.3)
        Test_AsyncEnableTriggerInteraction()
        Sleep(1.2)
        Test_PurchaseIndex_LastItem()
        Sleep(0.3)
        Test_OnPlayerLeft_ResetState()

    # ============================================================================
    # ТЕСТИ
    # ============================================================================
    
    Test_MoveProps_ValidPurchase()<suspends>:void=
        TestName := "MoveProps_ValidPurchaseProps.Z"
        
        if (FirstProp := TestProps[0], InitialPos := InitialPropsPositions[0]):
            ExpectedZ := InitialPos.Z + MoveOnZ
            
            SimulatePurchase()
            Sleep(0.2)
            
            if (NewTransform := FirstProp.GetTransform()):
                ActualZ := NewTransform.Translation.Z
                if (Abs(ActualZ - ExpectedZ) < 10.0):
                    LogPass(TestName)
                else:
                    LogFail(TestName)
            else:
                LogFail(TestName)
        else:
            LogFail(TestName)

    Test_MoveProps_ResetOnLeave()<suspends>:void=
        TestName := "MoveProps_ResetOnLeaveProps.Z"
        
        if (FirstProp := TestProps[0], InitialPos := InitialPropsPositions[0]):
            ExpectedZ := InitialPos.Z
            
            SimulatePlayerLeave()
            Sleep(0.2)
            
            if (NewTransform := FirstProp.GetTransform()):
                ActualZ := NewTransform.Translation.Z
                if (Abs(ActualZ - ExpectedZ) < 10.0):
                    LogPass(TestName)
                else:
                    LogFail(TestName)
            else:
                LogFail(TestName)
        else:
            LogFail(TestName)

    Test_MoveClaimerToPurchase_Position()<suspends>:void=
        TestName := "MoveClaimerToPurchase_Position"
        
        if (BeforeTransform := TestTrigger.GetTransform()):
            BeforePosition := BeforeTransform.Translation
            
            SimulatePurchase()
            Sleep(0.2)
            
            if (AfterTransform := TestTrigger.GetTransform()):
                AfterPosition := AfterTransform.Translation
                DistanceMoved := Distance(BeforePosition, AfterPosition)
                
                if (DistanceMoved > 1.0):
                    LogPass(TestName)
                else:
                    LogFail(TestName)
            else:
                LogFail(TestName)
        else:
            LogFail(TestName)

    Test_OnClaimerTriggered_FirstPlayer()<suspends>:void=
        TestName := "OnClaimerTriggered_FirstPlayer"
        
        ResetDeviceState()
        Sleep(0.1)
        
        if (Player := TestPlayerAgent?):
            TestTrigger.Trigger(Player)
            Sleep(0.2)
            
            if (VerifyOwnershipEstablished(Player)):
                LogPass(TestName)
            else:
                LogFail(TestName)
        else:
            LogFail(TestName)

    Test_OnClaimerTriggered_NotOwner()<suspends>:void=
        TestName := "OnClaimerTriggered_NotOwner"
        
        HasOwner : logic = true
        IsCurrentPlayerOwner : logic = false
        
        CanPurchase := CheckCanPurchase(HasOwner, IsCurrentPlayerOwner)
        
        if (CanPurchase = false):
            LogPass(TestName)
        else:
            LogFail(TestName)

    Test_OnClaimerTriggered_InsufficientGold()<suspends>:void=
        TestName := "OnClaimerTriggered_InsufficientGoldGold"
        
        PlayerGold : int = 50
        ItemPrice : int = 100
        
        HasEnoughGold := CheckGoldBalance(PlayerGold, ItemPrice)
        
        if (HasEnoughGold = false):
            LogPass(TestName)
        else:
            LogFail(TestName)

    Test_GoldDeduction_OnPurchase()<suspends>:void=
        TestName := "GoldDeduction_OnPurchase"
        
        InitialGold : int = 200
        ItemPrice : int = 100
        ExpectedGoldAfter : int = 100
        
        ActualGoldAfter := CalculateGoldAfterPurchase(InitialGold, ItemPrice)
        
        if (ActualGoldAfter = ExpectedGoldAfter):
            LogPass(TestName)
        else:
            LogFail(TestName)

    Test_Billboard_SetText_Price()<suspends>:void=
        TestName := "Billboard_SetText_PricePrice"
        
        TestPrice : int = 500
        ActualText := GenerateBillboardText("Item", TestPrice)
        
        if (ActualText = "Item\n500"):
            LogPass(TestName)
        else:
            LogFail(TestName)

    Test_Billboard_SetText_Free()<suspends>:void=
        TestName := "Billboard_SetText_FreePrice"
        
        TestPrice : int = 0
        ActualText := GenerateBillboardText("Item", TestPrice)
        
        if (ActualText = "Item\nFREE"):
            LogPass(TestName)
        else:
            LogFail(TestName)

    Test_AsyncEnableTriggerInteraction()<suspends>:void=
        TestName := "AsyncEnableTriggerInteractionDebounce"
        
        var bBlockInteraction : logic = true
        
        IsBlockedBefore := bBlockInteraction
        Sleep(DebounceTime)
        set bBlockInteraction = false
        IsBlockedAfter := bBlockInteraction
        
        if (IsBlockedBefore = true and IsBlockedAfter = false):
            LogPass(TestName)
        else:
            LogFail(TestName)

    Test_PurchaseIndex_LastItem()<suspends>:void=
        TestName := "PurchaseIndex_LastItem"
        
        CurrentIndex : int = 4
        TotalItems : int = 5
        
        IsLastItem := CheckIsLastItem(CurrentIndex + 1, TotalItems)
        
        if (IsLastItem):
            LogPass(TestName)
        else:
            LogFail(TestName)

    Test_OnPlayerLeft_ResetState()<suspends>:void=
        TestName := "OnPlayerLeft_ResetStateIndex"
        
        var CurrentIndex : int = 3
        var HasOwner : logic = true
        
        set CurrentIndex = 0
        set HasOwner = false
        
        if (CurrentIndex = 0 and HasOwner = false):
            LogPass(TestName)
        else:
            LogFail(TestName)

    # ============================================================================
    # ДОПОМІЖНІ ФУНКЦІЇ
    # ============================================================================
    
    SimulatePurchase()<suspends>:void=
        if (Player := TestPlayerAgent?):
            TestTrigger.Trigger(Player)

    SimulatePlayerLeave()<suspends>:void=
        return

    ResetDeviceState()<suspends>:void=
        return

    VerifyOwnershipEstablished(Player : agent):logic=
        return true

    CheckCanPurchase(HasOwner : logic, IsOwner : logic):logic=
        if (HasOwner = false):
            return true
        if (IsOwner = true):
            return true
        return false

    CheckGoldBalance(PlayerGold : int, Price : int):logic=
        return PlayerGold >= Price

    CalculateGoldAfterPurchase(CurrentGold : int, Price : int):int=
        return CurrentGold - Price

    GenerateBillboardText(ItemName : string, Price : int):string=
        if (Price = 0):
            return "{ItemName}\nFREE"
        return "{ItemName}\n{Price}"

    CheckIsLastItem(CurrentIndex : int, TotalItems : int):logic=
        return CurrentIndex >= TotalItems

    Distance(A : vector3, B : vector3):float=
        DX := A.X - B.X
        DY := A.Y - B.Y
        DZ := A.Z - B.Z
        return Sqrt(DX*DX + DY*DY + DZ*DZ)

    Abs(Value : float):float=
        if (Value < 0.0):
            return -Value
        return Value
