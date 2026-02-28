import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

interface TestResultBoxProps {
  children: React.ReactNode;
}

export const TestResultBox: React.FC<TestResultBoxProps> = ({ children }) => {
  return <View style={styles.resultBox}>{children}</View>;
};

interface TestResultItemProps {
  label: string;
  value: string | number | undefined;
  unit?: string;
}

export const TestResultItem: React.FC<TestResultItemProps> = ({ label, value, unit }) => {
  if (value === undefined || value === null) return null;
  
  return (
    <View style={styles.resultRow}>
      <Text style={styles.resultLabel}>{label}:</Text>
      <Text style={styles.resultValue}>
        {typeof value === 'number' ? String(value) : value} {unit || ''}
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  resultBox: {
    backgroundColor: '#f0f0f0',
    padding: 12,
    borderRadius: 8,
    marginTop: 4,
    marginBottom: 12,
  },
  resultRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  resultLabel: {
    fontSize: 14,
    color: '#666',
  },
  resultValue: {
    fontSize: 14,
    fontWeight: '500',
  },
});