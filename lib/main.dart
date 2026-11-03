import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UttarakhandTaxApp());
}

class UttarakhandTaxApp extends StatelessWidget {
  const UttarakhandTaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uttarakhand Property Tax Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F7FC), // Soft light blue bg
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F3A66), // Dark Navy Blue
          primary: const Color(0xFF0F3A66),
          secondary: const Color(0xFF1E88E5),
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const UttarakhandTaxCalculatorScreen(),
    );
  }
}

// ==========================================
// DATA MODELS & ENUMS
// ==========================================
enum CalculationMethod {
  selfAssessment('Self Assessment'),
  circleRate('Circle Rate'),
  rentBased('Estimated / Actual Rent');

  final String label;
  const CalculationMethod(this.label);
}

enum PropertyType {
  residential('Residential', Icons.home_rounded),
  commercial('Commercial', Icons.storefront_rounded),
  vacantLand('Vacant Land', Icons.landscape_rounded);

  final String label;
  final IconData icon;
  const PropertyType(this.label, this.icon);
}

enum StructureType {
  pucca('Pucca (RCC/Load Bearing)', 1.0),
  semiPucca('Semi-Pucca (Brick/Lime)', 0.7),
  kutcha('Kutcha (Temporary/Thatched)', 0.5);

  final String label;
  final double factor;
  const StructureType(this.label, this.factor);
}

enum OccupancyStatus {
  selfOccupied('Self-Occupied', 1.0),
  rented('Rented / Tenanted', 2.0);

  final String label;
  final double factor;
  const OccupancyStatus(this.label, this.factor);
}

class CalculationStep {
  final String title;
  final String formula;
  final String value;
  final String? note;

  const CalculationStep({
    required this.title,
    required this.formula,
    required this.value,
    this.note,
  });
}

class TaxResult {
  final double annualRentalValue;
  final double grossTax;
  final double cessAmount;
  final double rebateAmount;
  final double netTaxPayable;
  final List<CalculationStep> steps;

  const TaxResult({
    required this.annualRentalValue,
    required this.grossTax,
    required this.cessAmount,
    required this.rebateAmount,
    required this.netTaxPayable,
    required this.steps,
  });
}

// ==========================================
// MAIN SCREEN
// ==========================================
class UttarakhandTaxCalculatorScreen extends StatefulWidget {
  const UttarakhandTaxCalculatorScreen({super.key});

  @override
  State<UttarakhandTaxCalculatorScreen> createState() =>
      _UttarakhandTaxCalculatorScreenState();
}

class _UttarakhandTaxCalculatorScreenState
    extends State<UttarakhandTaxCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Selections
  CalculationMethod _selectedMethod = CalculationMethod.selfAssessment;
  PropertyType _selectedPropertyType = PropertyType.residential;
  StructureType _structureType = StructureType.pucca;
  OccupancyStatus _occupancyStatus = OccupancyStatus.selfOccupied;

  // Form Controllers
  final _carpetAreaController = TextEditingController(text: '850');
  final _coveredAreaController = TextEditingController(text: '1000');
  final _uncoveredAreaController = TextEditingController(text: '200');
  final _monthlyRateController = TextEditingController(
    text: '25',
  ); // ₹/sq.ft/month
  final _propertyMultiplierController = TextEditingController(text: '1.0');
  final _ulbTaxRateController = TextEditingController(text: '10.0'); // %

  // Circle Rate Controllers
  final _circleRateController = TextEditingController(text: '3200');
  bool _enableFiveYearAdjustment = false;
  final _yearsSinceRevisionController = TextEditingController(text: '6');
  final _fiveYearIndexationController = TextEditingController(
    text: '15.0',
  ); // %
  final _depreciationPercentController = TextEditingController(text: '10.0');

  // Rent Method Controllers
  final _monthlyRentController = TextEditingController(text: '12000');

  // Rebate & Cess
  final _cessRateController = TextEditingController(text: '2.0');
  final _rebateRateController = TextEditingController(text: '5.0');

  TaxResult? _result;

  @override
  void dispose() {
    _carpetAreaController.dispose();
    _coveredAreaController.dispose();
    _uncoveredAreaController.dispose();
    _monthlyRateController.dispose();
    _propertyMultiplierController.dispose();
    _ulbTaxRateController.dispose();
    _circleRateController.dispose();
    _yearsSinceRevisionController.dispose();
    _fiveYearIndexationController.dispose();
    _depreciationPercentController.dispose();
    _monthlyRentController.dispose();
    _cessRateController.dispose();
    _rebateRateController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _selectedMethod = CalculationMethod.selfAssessment;
      _selectedPropertyType = PropertyType.residential;
      _structureType = StructureType.pucca;
      _occupancyStatus = OccupancyStatus.selfOccupied;

      _carpetAreaController.text = '850';
      _coveredAreaController.text = '1000';
      _uncoveredAreaController.text = '200';
      _monthlyRateController.text = '25';
      _propertyMultiplierController.text = '1.0';
      _ulbTaxRateController.text = '10.0';

      _circleRateController.text = '3200';
      _enableFiveYearAdjustment = false;
      _yearsSinceRevisionController.text = '6';
      _fiveYearIndexationController.text = '15.0';
      _depreciationPercentController.text = '10.0';

      _monthlyRentController.text = '12000';
      _cessRateController.text = '2.0';
      _rebateRateController.text = '5.0';
      _result = null;
    });
  }

  void _calculateTax() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify required fields highlighted in red.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    final steps = <CalculationStep>[];

    final carpetArea = double.tryParse(_carpetAreaController.text) ?? 0.0;
    final coveredArea = double.tryParse(_coveredAreaController.text) ?? 0.0;
    final uncoveredArea = double.tryParse(_uncoveredAreaController.text) ?? 0.0;
    final propertyMultiplier =
        double.tryParse(_propertyMultiplierController.text) ?? 1.0;
    final ulbTaxRate = double.tryParse(_ulbTaxRateController.text) ?? 10.0;
    final cessRate = double.tryParse(_cessRateController.text) ?? 0.0;
    final rebateRate = double.tryParse(_rebateRateController.text) ?? 0.0;

    double arv = 0.0;

    if (_selectedMethod == CalculationMethod.selfAssessment) {
      // 1. SELF ASSESSMENT METHOD
      final monthlyRate = double.tryParse(_monthlyRateController.text) ?? 0.0;

      // Effective Area calculation
      final effectiveArea = _selectedPropertyType == PropertyType.vacantLand
          ? uncoveredArea
          : (coveredArea > 0 ? coveredArea : carpetArea) +
                (uncoveredArea * 0.5);

      steps.add(
        CalculationStep(
          title: 'Effective Taxable Area',
          formula: _selectedPropertyType == PropertyType.vacantLand
              ? 'Total Uncovered Plot Area'
              : 'Covered Area ($coveredArea) + [Uncovered Area ($uncoveredArea) × 0.50]',
          value: '${effectiveArea.toStringAsFixed(2)} sq. ft.',
          note: 'Open courtyard/terrace area is factored at 50% under municipal rules.',
        ),
      );

      // Coefficients
      final structureFactor = _selectedPropertyType == PropertyType.vacantLand
          ? 1.0
          : _structureType.factor;
      final occupancyFactor = _selectedPropertyType == PropertyType.vacantLand
          ? 1.0
          : _occupancyStatus.factor;

      double useFactor = 1.0;
      if (_selectedPropertyType == PropertyType.commercial) {
        useFactor = 2.0;
      } else if (_selectedPropertyType == PropertyType.vacantLand) {
        useFactor = 0.5;
      }

      final combinedMultiplier =
          structureFactor * occupancyFactor * useFactor * propertyMultiplier;

      steps.add(
        CalculationStep(
          title: 'Municipal Coefficients Applied',
          formula:
              'Structure (${structureFactor.toStringAsFixed(2)}) × Occupancy (${occupancyFactor.toStringAsFixed(2)}) × Use (${useFactor.toStringAsFixed(2)}) × Multiplier ($propertyMultiplier)',
          value: combinedMultiplier.toStringAsFixed(3),
        ),
      );

      // ARV = Area × Monthly Carpet Rate × 12 × Combined Multipliers
      arv = effectiveArea * monthlyRate * 12 * combinedMultiplier;
      steps.add(
        CalculationStep(
          title: 'Annual Rental Value (ARV)',
          formula:
              'Effective Area × Monthly Rate (₹$monthlyRate) × 12 months × Multipliers',
          value: '₹${arv.toStringAsFixed(2)}',
        ),
      );
    } else if (_selectedMethod == CalculationMethod.circleRate) {
      // 2. CIRCLE RATE METHOD
      final baseCircleRate = double.tryParse(_circleRateController.text) ?? 0.0;
      final depreciationPercent =
          double.tryParse(_depreciationPercentController.text) ?? 0.0;
      final totalArea = _selectedPropertyType == PropertyType.vacantLand
          ? uncoveredArea
          : (coveredArea > 0 ? coveredArea : carpetArea);

      double effectiveCircleRate = baseCircleRate;
      if (_enableFiveYearAdjustment) {
        final years = int.tryParse(_yearsSinceRevisionController.text) ?? 0;
        final indexPercent =
            double.tryParse(_fiveYearIndexationController.text) ?? 0.0;
        if (years >= 5) {
          final cycles = (years / 5).floor();
          final factor = pow(1.0 + (indexPercent / 100.0), cycles).toDouble();
          effectiveCircleRate = baseCircleRate * factor;
          steps.add(
            CalculationStep(
              title: '5-Year Circle Rate Adjustment',
              formula:
                  'Base Rate (₹$baseCircleRate) × (1 + $indexPercent%)^$cycles cycles',
              value: '₹${effectiveCircleRate.toStringAsFixed(2)} / sq.ft.',
              note:
                  '$years years unrevised -> $cycles five-year adjustment cycles applied.',
            ),
          );
        }
      }

      final grossCapitalValue =
          totalArea * effectiveCircleRate * propertyMultiplier;
      final depRate = _selectedPropertyType == PropertyType.vacantLand
          ? 0.0
          : depreciationPercent;
      final depreciatedValue = max(
        0.0,
        grossCapitalValue * (1.0 - (depRate / 100.0)),
      );

      steps.add(
        CalculationStep(
          title: 'Depreciated Capital Value',
          formula:
              'Area ($totalArea) × Circle Rate (₹${effectiveCircleRate.toStringAsFixed(2)}) - Dep ($depRate%)',
          value: '₹${depreciatedValue.toStringAsFixed(2)}',
        ),
      );

      // ARV yield statutory percentage
      final yieldPercent = _selectedPropertyType == PropertyType.vacantLand
          ? 4.0
          : 6.0;
      arv = depreciatedValue * (yieldPercent / 100.0);
      steps.add(
        CalculationStep(
          title: 'Annual Rental Value (ARV)',
          formula: 'Capital Value × Statutory Yield ($yieldPercent%)',
          value: '₹${arv.toStringAsFixed(2)}',
        ),
      );
    } else {
      // 3. ESTIMATED / ACTUAL RENT METHOD
      final monthlyRent = double.tryParse(_monthlyRentController.text) ?? 0.0;
      final grossRent = monthlyRent * 12.0;

      const maintenanceDeductionPercent = 10.0;
      final deductionAmount = grossRent * (maintenanceDeductionPercent / 100.0);
      arv = max(0.0, grossRent - deductionAmount);

      steps.add(
        CalculationStep(
          title: 'Gross Annual Rent',
          formula: 'Monthly Rent (₹$monthlyRent) × 12 months',
          value: '₹${grossRent.toStringAsFixed(2)}',
        ),
      );
      steps.add(
        CalculationStep(
          title: 'Statutory Maintenance Deduction',
          formula: 'Gross Rent - 10% Statutory Allowance',
          value: '-₹${deductionAmount.toStringAsFixed(2)}',
          note: 'Uttarakhand Municipal Act mandates 10% allowance for repair & maintenance.',
        ),
      );
      steps.add(
        CalculationStep(
          title: 'Net Annual Rental Value (Net ARV)',
          formula: 'Gross Rent - Deductions',
          value: '₹${arv.toStringAsFixed(2)}',
        ),
      );
    }

    // Gross Tax & Surcharges
    final grossTax = arv * (ulbTaxRate / 100.0);
    steps.add(
      CalculationStep(
        title: 'Gross Municipal Tax',
        formula:
            'ARV (₹${arv.toStringAsFixed(2)}) × ULB Tax Rate ($ulbTaxRate%)',
        value: '₹${grossTax.toStringAsFixed(2)}',
      ),
    );

    final cessAmount = grossTax * (cessRate / 100.0);
    if (cessRate > 0) {
      steps.add(
        CalculationStep(
          title: 'Cess / Surcharge',
          formula: 'Gross Tax × Cess ($cessRate%)',
          value: '₹${cessAmount.toStringAsFixed(2)}',
        ),
      );
    }

    final rebateAmount = grossTax * (rebateRate / 100.0);
    if (rebateRate > 0) {
      steps.add(
        CalculationStep(
          title: 'Rebate / Concession',
          formula: 'Gross Tax × Early Rebate ($rebateRate%)',
          value: '-₹${rebateAmount.toStringAsFixed(2)}',
        ),
      );
    }

    final netTax = max(0.0, grossTax + cessAmount - rebateAmount);
    steps.add(
      CalculationStep(
        title: 'Net Annual Property Tax Payable',
        formula: 'Gross Tax + Cess - Rebate',
        value: '₹${netTax.toStringAsFixed(2)}',
      ),
    );

    setState(() {
      _result = TaxResult(
        annualRentalValue: arv,
        grossTax: grossTax,
        cessAmount: cessAmount,
        rebateAmount: rebateAmount,
        netTaxPayable: netTax,
        steps: steps,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildMainCard(),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    _buildResultCard(),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. HEADER (WITH UTTARAKHAND STATE EMBLEM)
  // ==========================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08003366),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Official Uttarakhand State Logo Box
          Container(
            width: 58,
            height: 62,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCE8F2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A003366),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return CustomPaint(
                    painter: UttarakhandStateEmblemPainter(),
                    size: const Size(44, 44),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EFF9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'उत्तराखंड सरकार',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F3A66),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Uttarakhand Property Tax Calculator',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D253F),
                    letterSpacing: -0.2,
                  ),
                ),
                const Text(
                  'Calculate Your Property Tax Easily',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5A7184)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. MAIN CALCULATOR CARD
  // ==========================================
  Widget _buildMainCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C003366),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property Tax Calculator',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D253F),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Select the method and enter property details',
              style: TextStyle(fontSize: 13, color: Color(0xFF5A7184)),
            ),
            const SizedBox(height: 18),

            // Method Selector Tabs
            _buildMethodTabs(),
            const SizedBox(height: 22),

            // Property Type Selection Cards
            const Text(
              'Property Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D253F),
              ),
            ),
            const SizedBox(height: 10),
            _buildPropertyTypeCards(),
            const SizedBox(height: 22),

            // Dynamic Input Fields
            _buildDynamicFields(),
            const SizedBox(height: 24),

            // Action Buttons (Calculate & Reset)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _calculateTax,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3A66),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Calculate Tax',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _resetForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5A7184),
                    side: const BorderSide(color: Color(0xFFD6E4F0)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Calculation Method Tabs
  Widget _buildMethodTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F6FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE8F2)),
          ),
          child: Flex(
            direction: isNarrow ? Axis.vertical : Axis.horizontal,
            children: CalculationMethod.values.map((method) {
              final isSelected = _selectedMethod == method;
              final tab = InkWell(
                onTap: () => setState(() => _selectedMethod = method),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F3A66)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    method.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF334E68),
                    ),
                  ),
                ),
              );
              return isNarrow ? tab : Expanded(child: tab);
            }).toList(),
          ),
        );
      },
    );
  }

  // Property Type Cards (Residential, Commercial, Vacant Land)
  Widget _buildPropertyTypeCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 620;
        return Flex(
          direction: isSmall ? Axis.vertical : Axis.horizontal,
          children: PropertyType.values.map((type) {
            final isSelected = _selectedPropertyType == type;
            final card = InkWell(
              onTap: () => setState(() => _selectedPropertyType = type),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: EdgeInsets.only(
                  bottom: isSmall ? 8 : 0,
                  right: (!isSmall && type != PropertyType.vacantLand) ? 10 : 0,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0F7FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1E88E5)
                        : const Color(0xFFDCE8F2),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<PropertyType>(
                      value: type,
                      groupValue: _selectedPropertyType,
                      activeColor: const Color(0xFF1E88E5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPropertyType = val);
                        }
                      },
                    ),
                    Icon(
                      type.icon,
                      size: 20,
                      color: isSelected
                          ? const Color(0xFF1E88E5)
                          : const Color(0xFF627D98),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        type.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF0F3A66)
                              : const Color(0xFF334E68),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            return isSmall ? card : Expanded(child: card);
          }).toList(),
        );
      },
    );
  }

  // Dynamic Input Fields according to Method and Property
  Widget _buildDynamicFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedMethod == CalculationMethod.selfAssessment) ...[
          _buildResponsiveGrid([
            if (_selectedPropertyType != PropertyType.vacantLand) ...[
              _buildInputField(
                controller: _coveredAreaController,
                label: 'Covered Area',
                suffixText: 'sq. ft.',
              ),
              _buildInputField(
                controller: _carpetAreaController,
                label: 'Carpet Area',
                suffixText: 'sq. ft.',
              ),
            ],
            _buildInputField(
              controller: _uncoveredAreaController,
              label: _selectedPropertyType == PropertyType.vacantLand
                  ? 'Total Land Area'
                  : 'Uncovered Land Area',
              suffixText: 'sq. ft.',
            ),
            _buildInputField(
              controller: _monthlyRateController,
              label: 'Monthly Carpet Area Rate (Base UAV)',
              prefixText: '₹',
              suffixText: '/sq.ft',
            ),
            if (_selectedPropertyType != PropertyType.vacantLand) ...[
              _buildDropdownField<StructureType>(
                label: 'Structure Type',
                value: _structureType,
                items: StructureType.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _structureType = val);
                },
              ),
              _buildDropdownField<OccupancyStatus>(
                label: 'Occupancy Status',
                value: _occupancyStatus,
                items: OccupancyStatus.values
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(
                          o.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _occupancyStatus = val);
                },
              ),
            ],
            _buildInputField(
              controller: _propertyMultiplierController,
              label: 'Property Multiplier (Location/Road)',
              helperText: '1.0 standard',
            ),
            _buildInputField(
              controller: _ulbTaxRateController,
              label: 'ULB Tax Rate',
              suffixText: '%',
            ),
          ]),
        ] else if (_selectedMethod == CalculationMethod.circleRate) ...[
          _buildResponsiveGrid([
            _buildInputField(
              controller: _selectedPropertyType == PropertyType.vacantLand
                  ? _uncoveredAreaController
                  : _coveredAreaController,
              label: _selectedPropertyType == PropertyType.vacantLand
                  ? 'Total Plot Area'
                  : 'Covered / Built-up Area',
              suffixText: 'sq. ft.',
            ),
            _buildInputField(
              controller: _circleRateController,
              label: 'Official Circle Rate',
              prefixText: '₹',
              suffixText: '/sq.ft',
            ),
            if (_selectedPropertyType != PropertyType.vacantLand)
              _buildInputField(
                controller: _depreciationPercentController,
                label: 'Construction Depreciation',
                suffixText: '%',
              ),
            _buildInputField(
              controller: _propertyMultiplierController,
              label: 'Property Multiplier',
            ),
            _buildInputField(
              controller: _ulbTaxRateController,
              label: 'ULB Tax Rate',
              suffixText: '%',
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2EAF1)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Apply 5-Year Circle Rate Adjustment Rule',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D253F),
                    ),
                  ),
                  subtitle: const Text(
                    'Apply compounded indexation if circle rates are unrevised for 5+ years',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF5A7184)),
                  ),
                  value: _enableFiveYearAdjustment,
                  onChanged: (val) =>
                      setState(() => _enableFiveYearAdjustment = val),
                ),
                if (_enableFiveYearAdjustment) ...[
                  const SizedBox(height: 8),
                  _buildResponsiveGrid([
                    _buildInputField(
                      controller: _yearsSinceRevisionController,
                      label: 'Years Since Revision',
                      suffixText: 'years',
                    ),
                    _buildInputField(
                      controller: _fiveYearIndexationController,
                      label: 'Indexation per 5-Yr Cycle',
                      suffixText: '%',
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ] else if (_selectedMethod == CalculationMethod.rentBased) ...[
          _buildResponsiveGrid([
            _buildInputField(
              controller: _monthlyRentController,
              label: 'Monthly Actual / Estimated Rent',
              prefixText: '₹',
              suffixText: '/month',
            ),
            _buildInputField(
              controller: _ulbTaxRateController,
              label: 'ULB Tax Rate',
              suffixText: '%',
            ),
            _buildInputField(
              controller: _cessRateController,
              label: 'Municipal Cess / Surcharge',
              suffixText: '%',
            ),
            _buildInputField(
              controller: _rebateRateController,
              label: 'Early Payment Rebate',
              suffixText: '%',
            ),
          ]),
        ],
      ],
    );
  }

  // 2-Column Responsive Layout helper
  Widget _buildResponsiveGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 550;
        if (isSmall) {
          return Column(
            children: children
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ),
                )
                .toList(),
          );
        }
        final rows = <Widget>[];
        for (int i = 0; i < children.length; i += 2) {
          if (i + 1 < children.length) {
            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: children[i]),
                    const SizedBox(width: 14),
                    Expanded(child: children[i + 1]),
                  ],
                ),
              ),
            );
          } else {
            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: children[i]),
                    const SizedBox(width: 14),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            );
          }
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? prefixText,
    String? suffixText,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      style: const TextStyle(
        fontSize: 13.5,
        color: Color(0xFF0D253F),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF627D98)),
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF829AB1)),
        prefixText: prefixText != null ? '$prefixText ' : null,
        suffixText: suffixText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6E4F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6E4F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F3A66), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFCFE),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Required';
        if (double.tryParse(value) == null) return 'Invalid';
        return null;
      },
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      isExpanded: true,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF627D98)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6E4F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6E4F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F3A66), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFCFE),
      ),
    );
  }

  // ==========================================
  // 3. RESULT BREAKDOWN CARD
  // ==========================================
  Widget _buildResultCard() {
    final result = _result!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C003366),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header summary box
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCFE2F2)),
            ),
            child: Column(
              children: [
                const Text(
                  'Estimated Annual Property Tax',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF486581),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${result.netTaxPayable.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F3A66),
                  ),
                ),
                const Divider(height: 24, color: Color(0xFFD6E4F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol(
                      'Annual Rental Value',
                      '₹${result.annualRentalValue.toStringAsFixed(2)}',
                    ),
                    _buildStatCol(
                      'Gross Municipal Tax',
                      '₹${result.grossTax.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Detailed Mathematical Steps
          const Text(
            'Calculation Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D253F),
            ),
          ),
          const SizedBox(height: 10),

          ...result.steps.map(
            (step) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBFE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE4EDF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                      Text(
                        step.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D253F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.formula,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF486581),
                    ),
                  ),
                  if (step.note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      step.note!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF829AB1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF627D98)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F3A66),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. HIMALAYAN MOUNTAINS ILLUSTRATION
// ==========================================
class HimalayanMountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background ridge (Lighter soft blue)
    final backPaint = Paint()
      ..color = const Color(0xFFBFDDF4)
      ..style = PaintingStyle.fill;

    final backPath = Path()
      ..moveTo(0, h)
      ..lineTo(w * 0.25, h * 0.35)
      ..lineTo(w * 0.50, h * 0.60)
      ..lineTo(w * 0.80, h * 0.25)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(backPath, backPaint);

    // Foreground mountain peak (Slate navy-blue)
    final forePaint = Paint()
      ..color = const Color(0xFF8BBEE4)
      ..style = PaintingStyle.fill;

    final forePath = Path()
      ..moveTo(w * 0.1, h)
      ..lineTo(w * 0.55, h * 0.15)
      ..lineTo(w * 0.95, h)
      ..close();
    canvas.drawPath(forePath, forePaint);

    // Snowcap on primary peak (Crisp White)
    final snowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final snowPath = Path()
      ..moveTo(w * 0.55, h * 0.15)
      ..lineTo(w * 0.47, h * 0.40)
      ..lineTo(w * 0.52, h * 0.36)
      ..lineTo(w * 0.56, h * 0.42)
      ..lineTo(w * 0.62, h * 0.37)
      ..close();
    canvas.drawPath(snowPath, snowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// 5. UTTARAKHAND STATE EMBLEM PAINTER
// ==========================================
class UttarakhandStateEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Outer Diamond
    final diamondPath = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.95, h * 0.50)
      ..lineTo(w * 0.5, h * 0.92)
      ..lineTo(w * 0.05, h * 0.50)
      ..close();

    final bgPaint = Paint()..color = Colors.white;
    canvas.drawPath(diamondPath, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF152A75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.065
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(diamondPath, borderPaint);

    // 2. Red Diamond Peak
    final redApexPath = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.72, h * 0.27)
      ..lineTo(w * 0.5, h * 0.47)
      ..lineTo(w * 0.28, h * 0.27)
      ..close();

    final redPaint = Paint()..color = const Color(0xFFD32F2F);
    canvas.drawPath(redApexPath, redPaint);

    // 3. Ashoka Pillar Symbol (White)
    final ashokaPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.5, h * 0.20), w * 0.065, ashokaPaint);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.32),
        width: w * 0.16,
        height: h * 0.08,
      ),
      ashokaPaint,
    );

    // 4. Blue Mountain Ridges
    final mountainPaint = Paint()
      ..color = const Color(0xFF152A75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeJoin = StrokeJoin.round;

    final mtnPath = Path()
      ..moveTo(w * 0.18, h * 0.48)
      ..lineTo(w * 0.34, h * 0.28)
      ..lineTo(w * 0.50, h * 0.42)
      ..lineTo(w * 0.66, h * 0.28)
      ..lineTo(w * 0.82, h * 0.48);
    canvas.drawPath(mtnPath, mountainPaint);

    // 5. Four Blue River Streams
    final wavePaint = Paint()
      ..color = const Color(0xFF152A75)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final y = h * (0.52 + i * 0.09);
      final wave = Path()
        ..moveTo(w * 0.14, y)
        ..quadraticBezierTo(w * 0.35, y - h * 0.04, w * 0.55, y)
        ..quadraticBezierTo(w * 0.75, y + h * 0.04, w * 0.86, y)
        ..lineTo(w * 0.82, y + h * 0.035)
        ..quadraticBezierTo(w * 0.70, y + h * 0.06, w * 0.50, y + h * 0.03)
        ..quadraticBezierTo(w * 0.30, y - h * 0.01, w * 0.16, y + h * 0.03)
        ..close();
      canvas.drawPath(wave, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
