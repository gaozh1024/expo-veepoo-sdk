import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

interface DataSummaryItemProps {
  value: string | number;
  label: string;
}

export const DataSummaryItem: React.FC<DataSummaryItemProps> = ({ value, label }) => {
  return (
    <View style={styles.summaryItem}>
      <Text style={styles.summaryValue}>{value}</Text>
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
    justifyContent: 'space-around',
    flexWrap: 'wrap',
    marginBottom: 8,
  },
  summaryItem: {
    flex: 1,
    minWidth: '45%',
    alignItems: 'center',
    padding: 8,
    backgroundColor: '#fff',
    borderRadius: 8,
    margin: 4,
  },
  summaryValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  summaryLabel: {
    fontSize: 12,
    color: '#666',
    marginTop: 4,
  },
});