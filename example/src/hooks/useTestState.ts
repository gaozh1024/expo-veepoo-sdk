import { useState, useCallback } from 'react';
import type {
  HeartRateTestResult,
  BloodPressureTestResult,
  BloodOxygenTestResult,
  TemperatureTestResult,
  StressData,
  BloodGlucoseTestResult,
} from '@gaozh1024/expo-veepoo-sdk';
import type { TestType } from '../types';

export interface TestStateData {
  isTesting: string | null;
  heartRateResult: HeartRateTestResult | null;
  bloodPressureResult: BloodPressureTestResult | null;
  bloodOxygenResult: BloodOxygenTestResult | null;
  temperatureResult: TemperatureTestResult | null;
  stressData: StressData | null;
  bloodGlucoseResult: BloodGlucoseTestResult | null;
  heartRateProgress: number;
}

export interface TestActions {
  setIsTesting: (value: string | null) => void;
  setHeartRateResult: (value: HeartRateTestResult | null) => void;
  setBloodPressureResult: (value: BloodPressureTestResult | null) => void;
  setBloodOxygenResult: (value: BloodOxygenTestResult | null) => void;
  setTemperatureResult: (value: TemperatureTestResult | null) => void;
  setStressData: (value: StressData | null) => void;
  setBloodGlucoseResult: (value: BloodGlucoseTestResult | null) => void;
  setHeartRateProgress: (value: number) => void;
  updateTestResult: (testType: TestType, data: unknown) => void;
  clearTestState: () => void;
}

export type UseTestState = TestStateData & TestActions;

export const useTestState = (): UseTestState => {
  const [isTesting, setIsTesting] = useState<string | null>(null);
  const [heartRateResult, setHeartRateResult] = useState<HeartRateTestResult | null>(null);
  const [bloodPressureResult, setBloodPressureResult] = useState<BloodPressureTestResult | null>(null);
  const [bloodOxygenResult, setBloodOxygenResult] = useState<BloodOxygenTestResult | null>(null);
  const [temperatureResult, setTemperatureResult] = useState<TemperatureTestResult | null>(null);
  const [stressData, setStressData] = useState<StressData | null>(null);
  const [bloodGlucoseResult, setBloodGlucoseResult] = useState<BloodGlucoseTestResult | null>(null);
  const [heartRateProgress, setHeartRateProgress] = useState(0);

  const updateTestResult = useCallback((testType: TestType, data: unknown) => {
    switch (testType) {
      case 'heartRate':
        setHeartRateResult(data as HeartRateTestResult);
        break;
      case 'bloodPressure':
        setBloodPressureResult(data as BloodPressureTestResult);
        break;
      case 'bloodOxygen':
        setBloodOxygenResult(data as BloodOxygenTestResult);
        break;
      case 'temperature':
        setTemperatureResult(data as TemperatureTestResult);
        break;
      case 'stress':
        setStressData(data as StressData);
        break;
      case 'bloodGlucose':
        setBloodGlucoseResult(data as BloodGlucoseTestResult);
        break;
    }
  }, []);

  const clearTestState = useCallback(() => {
    setIsTesting(null);
    setHeartRateProgress(0);
  }, []);

  return {
    isTesting,
    heartRateResult,
    bloodPressureResult,
    bloodOxygenResult,
    temperatureResult,
    stressData,
    bloodGlucoseResult,
    heartRateProgress,
    setIsTesting,
    setHeartRateResult,
    setBloodPressureResult,
    setBloodOxygenResult,
    setTemperatureResult,
    setStressData,
    setBloodGlucoseResult,
    setHeartRateProgress,
    updateTestResult,
    clearTestState,
  };
};