import { useState, useCallback, useMemo } from 'react';
import type { HalfHourData, SportStepData } from '@gaozh1024/expo-veepoo-sdk';
import type { SleepDataItem } from '../types';

export interface DataState {
  isLoadingData: boolean;
  loadDataProgress: number;
  originDataList: HalfHourData[];
  sleepDataList: SleepDataItem[];
  sportStepData: SportStepData | null;
}

export interface DataActions {
  setIsLoadingData: (value: boolean) => void;
  setLoadDataProgress: (value: number) => void;
  addOriginData: (data: HalfHourData) => void;
  setSleepDataList: (value: SleepDataItem[]) => void;
  setSportStepData: (value: SportStepData | null) => void;
  clearOriginData: () => void;
  clearAllData: () => void;
}

export type UseDataState = DataState & DataActions & {
  sportSummary: {
    totalSteps: number;
    totalDistance: number;
    totalCalories: number;
    avgHeartRate: number;
  };
};

export const useDataState = (): UseDataState => {
  const [isLoadingData, setIsLoadingData] = useState(false);
  const [loadDataProgress, setLoadDataProgress] = useState(0);
  const [originDataList, setOriginDataList] = useState<HalfHourData[]>([]);
  const [sleepDataList, setSleepDataList] = useState<SleepDataItem[]>([]);
  const [sportStepData, setSportStepData] = useState<SportStepData | null>(null);

  const sportSummary = useMemo(() => {
    const totalSteps = originDataList.reduce((sum, d) => sum + (d.stepValue || 0), 0);
    const totalDistance = originDataList.reduce((sum, d) => sum + (d.disValue || 0), 0);
    const totalCalories = originDataList.reduce((sum, d) => sum + (d.calValue || 0), 0);
    const heartRateData = originDataList.filter(d => d.heartValue && d.heartValue > 0);
    const avgHeartRate = heartRateData.length > 0
      ? Math.round(heartRateData.reduce((sum, d) => sum + (d.heartValue || 0), 0) / heartRateData.length)
      : 0;
    return { totalSteps, totalDistance, totalCalories, avgHeartRate };
  }, [originDataList]);

  const addOriginData = useCallback((data: HalfHourData) => {
    setOriginDataList((prev) => [...prev, data]);
  }, []);

  const clearOriginData = useCallback(() => {
    setOriginDataList([]);
  }, []);

  const clearAllData = useCallback(() => {
    setIsLoadingData(false);
    setLoadDataProgress(0);
    setOriginDataList([]);
    setSleepDataList([]);
    setSportStepData(null);
  }, []);

  return {
    isLoadingData,
    loadDataProgress,
    originDataList,
    sleepDataList,
    sportStepData,
    sportSummary,
    setIsLoadingData,
    setLoadDataProgress,
    addOriginData,
    setSleepDataList,
    setSportStepData,
    clearOriginData,
    clearAllData,
  };
};