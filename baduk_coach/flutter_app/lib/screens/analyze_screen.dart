import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/api_models.dart';

/// 기보 분석 화면
class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  final _sgfController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  StyleResult? _result;
  String? _error;

  // 샘플 SGF
  final _sampleSgf = '''(;GM[1]FF[4]SZ[19]KM[6.5]
;B[pd];W[dp];B[pq];W[dd];B[fc];W[cf];B[jd];W[qc];B[qd];W[pc]
;B[od];W[rc];B[rd];W[rb];B[nc];W[nb];B[mb];W[ob];B[mc];W[qn]
;B[qo];W[pn];B[np];W[qk];B[cn];W[fq];B[bp];W[cq];B[ck];W[ch]
;B[po];W[on];B[no];W[nn];B[mn];W[mm];B[ln];W[lm];B[kn];W[km])''';

  @override
  void dispose() {
    _sgfController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_sgfController.text.isEmpty) {
      setState(() => _error = 'SGF를 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _apiService.analyzeSgf(
        'user123', // TODO: 실제 사용자 ID로 교체
        _sgfController.text,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기보 스타일 분석'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SGF 입력
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SGF 기보 입력',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _sgfController.text = _sampleSgf;
                          },
                          child: const Text('샘플 불러오기'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _sgfController,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: '(;GM[1]FF[4]SZ[19]...',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _analyze,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('분석하기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 에러 메시지
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ),

            // 분석 결과
            if (_result != null) ...[
              // 스타일 이름
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        '당신의 바둑 스타일',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result!.styleNameKo,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Feature 수치
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '상세 지표',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._result!.features.entries.map((entry) {
                        return _buildFeatureBar(
                          _getFeatureLabel(entry.key),
                          entry.value,
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 코칭 텍스트
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            '코칭 조언',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _result!.coachingText,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('${(value * 100).toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  String _getFeatureLabel(String key) {
    const labels = {
      'big_loss_ratio': '큰 손해 비율',
      'center_ratio': '중앙 선호도',
      'invasion_ratio': '침투 빈도',
      'fight_ratio': '전투 비율',
      'territory_ratio': '실리 비율',
    };
    return labels[key] ?? key;
  }
}
