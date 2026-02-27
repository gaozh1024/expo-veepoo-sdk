import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

interface EmptyDataBoxProps {
  title: string;
  hint: string;
}

export const EmptyDataBox: React.FC<EmptyDataBoxProps> = ({ title, hint }) => {
  return (
    <View style={styles.emptyDataBox}>
      <Text style={styles.emptyDataText}>{title}</Text>
      <Text style={styles.emptyDataHint}>{hint}</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  emptyDataBox: {
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f9f9f9',
    borderRadius: 8,
  },
  emptyDataText: {
    fontSize: 16,
    color: '#666',
    fontWeight: '500',
  },
  emptyDataHint: {
    fontSize: 12,
    color: '#999',
    marginTop: 8,
    textAlign: 'center',
  },
});