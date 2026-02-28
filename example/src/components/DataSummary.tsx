import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Colors, Spacing, BorderRadius, FontSize, Shadows } from '../theme';

interface DataSummaryItemProps {
  value: string | number;
  label: string;
  icon?: string;
  color?: string;
}

export const DataSummaryItem: React.FC<DataSummaryItemProps> = ({ 
  value, 
  label,
  icon,
  color = Colors.primary,
}) => {
  return (
    <View style={[styles.summaryItem, Shadows.md]}>
      {icon && <Text style={styles.icon}>{icon}</Text>}
      <Text style={[styles.summaryValue, { color }]}>{value}</Text>
      <Text style={styles.summaryLabel}>{label}</Text>
    </View>
  );
};

interface DataSummaryGridProps {
  children: React.ReactNode;
}

export const DataSummaryGrid: React.FC<DataSummaryGridProps> = ({ children }) => {
  return <View style={styles.summaryGrid}>{children}</View>;
};

const styles = StyleSheet.create({
  summaryGrid: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    flexWrap: 'wrap',
    marginHorizontal: -Spacing.xs,
  },
  summaryItem: {
    flex: 1,
    minWidth: '48%',
    alignItems: 'center',
    paddingVertical: Spacing.lg,
    paddingHorizontal: Spacing.md,
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.lg,
    margin: Spacing.xs,
    borderWidth: 1,
    borderColor: Colors.divider,
  },
  icon: {
    fontSize: 24,
    marginBottom: Spacing.xs,
  },
  summaryValue: {
    fontSize: FontSize.xxl,
    fontWeight: 'bold',
  },
  summaryLabel: {
    fontSize: FontSize.xs,
    color: Colors.text.secondary,
    marginTop: Spacing.xs,
    textAlign: 'center',
  },
});