import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Spacing, BorderRadius, FontSize, Shadows } from '../theme';
import type { SleepDataItem } from '../types';

interface SleepCardProps {
  data: SleepDataItem;
}

const formatDuration = (minutes: number): string => {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return mins > 0 ? `${hours}h ${mins}m` : `${hours}h`;
};

const getQualityColor = (quality: number): string => {
  if (quality >= 4) return Colors.success;
  if (quality >= 3) return Colors.warning;
  return Colors.danger;
};

const getQualityLabel = (quality: number): string => {
  if (quality >= 4) return '优秀';
  if (quality >= 3) return '良好';
  if (quality >= 2) return '一般';
  return '较差';
};

const SleepProgressBar: React.FC<{ deep: number; light: number; total: number }> = ({ 
  deep, 
  light, 
  total 
}) => {
  const deepPercent = total > 0 ? (deep / total) * 100 : 0;
  const lightPercent = total > 0 ? (light / total) * 100 : 0;

  return (
    <View style={progressStyles.container}>
      <View style={progressStyles.bar}>
        <View style={[progressStyles.deepSegment, { width: `${deepPercent}%` }]} />
        <View style={[progressStyles.lightSegment, { width: `${lightPercent}%` }]} />
      </View>
      <View style={progressStyles.legend}>
        <View style={progressStyles.legendItem}>
          <View style={[progressStyles.legendDot, { backgroundColor: Colors.sleep.deep }]} />
          <Text style={progressStyles.legendText}>深睡 {formatDuration(deep)}</Text>
        </View>
        <View style={progressStyles.legendItem}>
          <View style={[progressStyles.legendDot, { backgroundColor: Colors.sleep.light }]} />
          <Text style={progressStyles.legendText}>浅睡 {formatDuration(light)}</Text>
        </View>
      </View>
    </View>
  );
};

const progressStyles = StyleSheet.create({
  container: {
    marginTop: Spacing.md,
  },
  bar: {
    flexDirection: 'row',
    height: 8,
    borderRadius: BorderRadius.full,
    backgroundColor: Colors.divider,
    overflow: 'hidden',
  },
  deepSegment: {
    backgroundColor: Colors.sleep.deep,
  },
  lightSegment: {
    backgroundColor: Colors.sleep.light,
  },
  legend: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginTop: Spacing.sm,
    gap: Spacing.lg,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  legendDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: Spacing.xs,
  },
  legendText: {
    fontSize: FontSize.xs,
    color: Colors.text.secondary,
  },
});

export const SleepCard: React.FC<SleepCardProps> = ({ data }) => {
  const qualityColor = getQualityColor(data.sleepQuality);
  const qualityLabel = getQualityLabel(data.sleepQuality);

  return (
    <View style={[styles.card, Shadows.md]}>
      <View style={styles.header}>
        <View style={styles.timeContainer}>
          <Text style={styles.moonIcon}>🌙</Text>
          <View>
            <Text style={styles.sleepTime}>{data.sleepTime}</Text>
            <Text style={styles.wakeTime}>→ {data.wakeTime}</Text>
          </View>
        </View>
        <View style={[styles.qualityBadge, { backgroundColor: qualityColor + '20' }]}>
          <Text style={[styles.qualityScore, { color: qualityColor }]}>
            {data.sleepQuality}/5
          </Text>
          <Text style={[styles.qualityLabel, { color: qualityColor }]}>
            {qualityLabel}
          </Text>
        </View>
      </View>

      <SleepProgressBar 
        deep={data.deepSleepMinutes} 
        light={data.lightSleepMinutes} 
        total={data.totalSleepMinutes} 
      />

      <View style={styles.statsGrid}>
        <View style={styles.statItem}>
          <Text style={styles.statValue}>{formatDuration(data.totalSleepMinutes)}</Text>
          <Text style={styles.statLabel}>总睡眠</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statValue}>{data.wakeUpCount}</Text>
          <Text style={styles.statLabel}>清醒次数</Text>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: Colors.card.sleep,
    borderRadius: BorderRadius.lg,
    padding: Spacing.lg,
    marginBottom: Spacing.md,
    borderWidth: 1,
    borderColor: Colors.primary + '20',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: Spacing.sm,
  },
  timeContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  moonIcon: {
    fontSize: 28,
    marginRight: Spacing.md,
  },
  sleepTime: {
    fontSize: FontSize.lg,
    fontWeight: '600',
    color: Colors.text.primary,
  },
  wakeTime: {
    fontSize: FontSize.sm,
    color: Colors.text.secondary,
    marginTop: 2,
  },
  qualityBadge: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.md,
    alignItems: 'center',
  },
  qualityScore: {
    fontSize: FontSize.xl,
    fontWeight: 'bold',
  },
  qualityLabel: {
    fontSize: FontSize.xs,
    marginTop: 2,
  },
  statsGrid: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: Spacing.md,
    paddingTop: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: Colors.divider,
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    fontSize: FontSize.xl,
    fontWeight: 'bold',
    color: Colors.text.primary,
  },
  statLabel: {
    fontSize: FontSize.xs,
    color: Colors.text.secondary,
    marginTop: 2,
  },
});