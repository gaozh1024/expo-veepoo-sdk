import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native';
import { Colors, Spacing, BorderRadius, FontSize, Shadows } from '../theme';

interface TestButtonGroupProps {
  testType: string;
  isTesting: string | null;
  onStart: () => void;
  onStop: () => void;
  startTitle: string;
  stopTitle: string;
}

const TEST_ICONS: Record<string, string> = {
  heartRate: '❤️',
  bloodPressure: '🩸',
  bloodOxygen: '💨',
  temperature: '🌡️',
  stress: '🧠',
  bloodGlucose: '🩸',
};

export const TestButtonGroup: React.FC<TestButtonGroupProps> = ({
  testType,
  isTesting,
  onStart,
  onStop,
  startTitle,
}) => {
  const isThisTestActive = isTesting === testType;
  const isOtherTestActive = isTesting !== null && !isThisTestActive;
  const icon = TEST_ICONS[testType] || '🔬';

  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={[
          styles.button,
          isThisTestActive && styles.buttonActive,
          isOtherTestActive && styles.buttonDisabled,
        ]}
        onPress={isThisTestActive ? onStop : onStart}
        disabled={isOtherTestActive}
        activeOpacity={0.8}
      >
        {isThisTestActive ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="small" color={Colors.text.inverse} />
            <Text style={styles.buttonTextActive}>测试中...</Text>
          </View>
        ) : (
          <View style={styles.buttonContent}>
            <Text style={styles.icon}>{icon}</Text>
            <Text style={styles.buttonText}>{startTitle}</Text>
          </View>
        )}
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginVertical: Spacing.sm,
  },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    backgroundColor: Colors.primary,
    borderRadius: BorderRadius.lg,
    ...Shadows.md,
  },
  buttonActive: {
    backgroundColor: Colors.danger,
  },
  buttonDisabled: {
    backgroundColor: Colors.border,
    opacity: 0.6,
  },
  buttonContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  loadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  icon: {
    fontSize: FontSize.lg,
    marginRight: Spacing.sm,
  },
  buttonText: {
    color: Colors.text.inverse,
    fontSize: FontSize.md,
    fontWeight: '600',
  },
  buttonTextActive: {
    color: Colors.text.inverse,
    fontSize: FontSize.md,
    fontWeight: '600',
    marginLeft: Spacing.sm,
  },
});