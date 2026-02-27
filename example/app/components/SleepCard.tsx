import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

interface SleepStatItemProps {
  value: string | number;
  label: string;
}

export const SleepStatItem: React.FC<SleepStatItemProps> = ({ value, label }) => {
  return (
    <View style={styles.sleepStatItem}>
      <Text style={styles.sleepStatValue}>{value}</Text>
      <Text style={styles.sleepStatLabel}>{label}</Text>
    </View>
  );
};

interface SleepCardProps {
  sleepTime: string;
  wakeTime: string;
  sleepLevel: number;
  deepSleepDuration: string | number;
  lightSleepDuration: string | number;
  totalSleepHours: number;
  totalSleepMinutes: number;
  wakeUpCount: number;
}

export const SleepCard: React.FC<SleepCardProps> = ({
  sleepTime,
  wakeTime,
  sleepLevel,
  deepSleepDuration,
  lightSleepDuration,
  totalSleepHours,
  totalSleepMinutes,
  wakeUpCount,
}) => {
  return (
    <View style={styles.sleepCard}>
      <View style={styles.sleepHeader}>
        <Text style={styles.sleepTime}>
          {sleepTime} → {wakeTime}
        </Text>
        <Text style={styles.sleepScore}>评分: {sleepLevel}/5</Text>
      </View>
      <View style={styles.sleepStats}>
        <SleepStatItem value={deepSleepDuration} label="深睡(小时)" />
        <SleepStatItem value={lightSleepDuration} label="浅睡(小时)" />
        <SleepStatItem 
          value={`${totalSleepHours}h ${totalSleepMinutes}m`} 
          label="总睡眠" 
        />
        <SleepStatItem value={wakeUpCount} label="清醒次数" />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  sleepCard: {
    backgroundColor: '#f0f4ff',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  sleepHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  sleepTime: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
  },
  sleepScore: {
    fontSize: 14,
    fontWeight: '600',
    color: '#007AFF',
  },
  sleepStats: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  sleepStatItem: {
    width: '50%',
    padding: 6,
    alignItems: 'center',
  },
  sleepStatValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  sleepStatLabel: {
    fontSize: 11,
    color: '#666',
    marginTop: 2,
  },
});