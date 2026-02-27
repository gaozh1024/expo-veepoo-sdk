import React from 'react';
import { View, Text, Button, StyleSheet } from 'react-native';

interface TestButtonGroupProps {
  testType: string;
  isTesting: string | null;
  onStart: () => void;
  onStop: () => void;
  startTitle: string;
  stopTitle: string;
}

export const TestButtonGroup: React.FC<TestButtonGroupProps> = ({
  testType,
  isTesting,
  onStart,
  onStop,
  startTitle,
  stopTitle,
}) => {
  const isThisTestActive = isTesting === testType;
  const isOtherTestActive = isTesting !== null && !isThisTestActive;
  
  return (
    <View style={styles.testButtonRow}>
      <Button
        title={isThisTestActive ? '测试中...' : startTitle}
        onPress={onStart}
        disabled={isOtherTestActive}
      />
      <Button
        title={isThisTestActive ? '停止' : '停止'}
        onPress={onStop}
        disabled={!isThisTestActive}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  testButtonRow: {
    marginVertical: 8,
  },
});