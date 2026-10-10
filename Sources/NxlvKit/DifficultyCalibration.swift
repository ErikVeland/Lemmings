import Foundation

/// Heuristic calibration, not psychological units. Keep changes versioned with DifficultyModel.
public enum DifficultyCalibration {
    public static let basicTechnique = 65.0
    public static let advancedCombination = 85.0
    public static let distinctSkill = 45.0
    public static let dependentSkillChange = 65.0
    public static let additionalWorker = 35.0
    public static let logarithmicRepetition = 12.0
    public static let concurrentWorker = 180.0
    public static let rapidRegionSwitch = 70.0
    public static let depletedResources = 600.0
    public static let rescuePressure = 180.0
    public static let timePressure = 220.0
    public static let deductionDependency = 35.0
    public static let unusedSkillChoice = 20.0
    public static let interactingSystem = 30.0
    public static let timingSensitivity = 550.0
    public static let criticalAction = 85.0
    public static let criticalActionExponent = 1.35
    public static let selectionSensitivity = 100.0
    // Weak priors when the solution is unknown. No execution requirement is inferred.
    public static let priorSkillChoice = 18.0
    public static let priorTechniqueCeiling = 180.0
    public static let priorRescuePressure = 250.0
    public static let priorDeductionChoice = 25.0
    public static let priorDeductionSystem = 20.0
    public static let priorDeductionCeiling = 400.0
    public static let metadataCalibrationWeight = 0.15
}

public enum ProgressionWeights {
    public static let uncertainty = 50.0
    public static let previousUncertainty = 10.0
    public static let componentSlack = 120.0
    public static let componentScale = 100.0
    public static let componentJump = 12.0
    public static let stepDistance = 0.2
    public static let jumpScale = 40.0
    public static let jumpPenalty = 18.0
    public static let newConcept = 12.0
    public static let newAdvancedConcept = 35.0
    public static let missingPrerequisite = 70.0
    public static let repetition = 6.0
    public static let samePack = 2.0
    public static let lowPrecision = 0.65
    public static let lowConcurrency = 0.1
    public static let unknownPrecision = 40.0
    public static let executionBonus = 0.025
    public static let maximumExecutionBonus = 20.0
}
