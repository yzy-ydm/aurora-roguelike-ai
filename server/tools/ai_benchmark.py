"""
AI性能测试工具

测试：
- 并发请求数量
- 平均响应时间
- 成功率
- Fallback比例

输出：
- 性能报告
"""

import asyncio
import aiohttp
import time
import json
import os
from typing import List, Dict, Any
from dataclasses import dataclass
from datetime import datetime


# 配置
BASE_URL = "http://localhost:8001"
TOKEN = "aurora-roguelike-ai-key-2024"

# 测试端点
ENDPOINTS = [
    {
        "name": "floor",
        "path": "/api/generate/floor",
        "data": {"floor_level": 1, "player_level": 1}
    },
    {
        "name": "room",
        "path": "/api/generate/room",
        "data": {"room_id": 1, "room_type": "combat", "floor_level": 1, "player_level": 1}
    },
    {
        "name": "event",
        "path": "/api/generate/event",
        "data": {"room_type": "combat", "player_level": 1}
    },
    {
        "name": "upgrade",
        "path": "/api/generate/upgrade",
        "data": {"player_level": 5}
    },
    {
        "name": "difficulty",
        "path": "/api/generate/difficulty",
        "data": {"context": {"player_level": 5, "combat_style": "balanced"}}
    }
]


@dataclass
class RequestResult:
    """请求结果"""
    endpoint: str
    success: bool
    response_time: float
    status_code: int
    from_cache: bool = False
    fallback_used: bool = False
    error: str = ""


class AIBenchmark:
    """AI性能测试"""

    def __init__(self, base_url: str = BASE_URL, token: str = TOKEN):
        self.base_url = base_url
        self.token = token
        self.results: List[RequestResult] = []

    async def make_request(
        self,
        session: aiohttp.ClientSession,
        endpoint: Dict[str, Any]
    ) -> RequestResult:
        """发送单个请求"""
        url = f"{self.base_url}{endpoint['path']}"
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.token}"
        }

        start_time = time.time()

        try:
            async with session.post(
                url,
                json=endpoint["data"],
                headers=headers
            ) as response:
                response_time = time.time() - start_time
                status_code = response.status

                if status_code == 200:
                    data = await response.json()
                    from_cache = data.get("from_cache", False)
                    ai_mode = data.get("ai_mode", "unknown")
                    fallback_used = "fallback" in ai_mode.lower()

                    return RequestResult(
                        endpoint=endpoint["name"],
                        success=True,
                        response_time=response_time,
                        status_code=status_code,
                        from_cache=from_cache,
                        fallback_used=fallback_used
                    )
                else:
                    return RequestResult(
                        endpoint=endpoint["name"],
                        success=False,
                        response_time=response_time,
                        status_code=status_code,
                        error=f"HTTP {status_code}"
                    )

        except Exception as e:
            response_time = time.time() - start_time
            return RequestResult(
                endpoint=endpoint["name"],
                success=False,
                response_time=response_time,
                status_code=0,
                error=str(e)
            )

    async def run_single_test(
        self,
        session: aiohttp.ClientSession,
        endpoint: Dict[str, Any]
    ) -> RequestResult:
        """运行单个测试"""
        return await self.make_request(session, endpoint)

    async def run_concurrent_test(
        self,
        concurrency: int = 10,
        requests_per_endpoint: int = 5
    ) -> List[RequestResult]:
        """运行并发测试"""
        results = []

        async with aiohttp.ClientSession() as session:
            tasks = []

            for endpoint in ENDPOINTS:
                for _ in range(requests_per_endpoint):
                    tasks.append(self.run_single_test(session, endpoint))

            # 并发执行
            if concurrency > 0:
                semaphore = asyncio.Semaphore(concurrency)

                async def limited_request(task):
                    async with semaphore:
                        return await task

                results = await asyncio.gather(
                    *[limited_request(task) for task in tasks]
                )
            else:
                results = await asyncio.gather(*tasks)

        return results

    async def run_sequential_test(
        self,
        requests_per_endpoint: int = 3
    ) -> List[RequestResult]:
        """运行顺序测试"""
        results = []

        async with aiohttp.ClientSession() as session:
            for endpoint in ENDPOINTS:
                for _ in range(requests_per_endpoint):
                    result = await self.run_single_test(session, endpoint)
                    results.append(result)

        return results

    def analyze_results(self, results: List[RequestResult]) -> Dict[str, Any]:
        """分析测试结果"""
        if not results:
            return {"error": "No results to analyze"}

        # 总体统计
        total_requests = len(results)
        successful = sum(1 for r in results if r.success)
        failed = total_requests - successful
        from_cache = sum(1 for r in results if r.from_cache)
        fallback_used = sum(1 for r in results if r.fallback_used)

        # 响应时间统计
        response_times = [r.response_time for r in results if r.success]
        avg_response_time = sum(response_times) / len(response_times) if response_times else 0
        min_response_time = min(response_times) if response_times else 0
        max_response_time = max(response_times) if response_times else 0

        # 各端点统计
        endpoint_stats = {}
        for endpoint in ENDPOINTS:
            endpoint_name = endpoint["name"]
            endpoint_results = [r for r in results if r.endpoint == endpoint_name]

            if endpoint_results:
                endpoint_successful = sum(1 for r in endpoint_results if r.success)
                endpoint_times = [r.response_time for r in endpoint_results if r.success]

                endpoint_stats[endpoint_name] = {
                    "total": len(endpoint_results),
                    "successful": endpoint_successful,
                    "failed": len(endpoint_results) - endpoint_successful,
                    "success_rate": endpoint_successful / len(endpoint_results),
                    "avg_response_time": sum(endpoint_times) / len(endpoint_times) if endpoint_times else 0,
                    "from_cache": sum(1 for r in endpoint_results if r.from_cache),
                    "fallback_used": sum(1 for r in endpoint_results if r.fallback_used)
                }

        return {
            "summary": {
                "total_requests": total_requests,
                "successful": successful,
                "failed": failed,
                "success_rate": successful / total_requests,
                "from_cache": from_cache,
                "fallback_used": fallback_used,
                "cache_hit_rate": from_cache / total_requests
            },
            "response_time": {
                "average": round(avg_response_time, 3),
                "min": round(min_response_time, 3),
                "max": round(max_response_time, 3)
            },
            "endpoints": endpoint_stats
        }

    def generate_report(self, analysis: Dict[str, Any]) -> str:
        """生成测试报告"""
        report = []
        report.append("=" * 60)
        report.append("Aurora-Roguelike-AI 性能测试报告")
        report.append("=" * 60)
        report.append(f"测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"目标服务器: {self.base_url}")
        report.append("")

        # 总体统计
        summary = analysis["summary"]
        report.append("【总体统计】")
        report.append(f"  总请求数: {summary['total_requests']}")
        report.append(f"  成功请求: {summary['successful']}")
        report.append(f"  失败请求: {summary['failed']}")
        report.append(f"  成功率: {summary['success_rate']:.2%}")
        report.append(f"  缓存命中: {summary['from_cache']}")
        report.append(f"  缓存命中率: {summary['cache_hit_rate']:.2%}")
        report.append(f"  使用降级: {summary['fallback_used']}")
        report.append("")

        # 响应时间
        response_time = analysis["response_time"]
        report.append("【响应时间】")
        report.append(f"  平均: {response_time['average']:.3f}s")
        report.append(f"  最小: {response_time['min']:.3f}s")
        report.append(f"  最大: {response_time['max']:.3f}s")
        report.append("")

        # 各端点统计
        report.append("【各端点统计】")
        for endpoint_name, stats in analysis["endpoints"].items():
            report.append(f"  {endpoint_name}:")
            report.append(f"    请求数: {stats['total']}")
            report.append(f"    成功率: {stats['success_rate']:.2%}")
            report.append(f"    平均响应时间: {stats['avg_response_time']:.3f}s")
            report.append(f"    缓存命中: {stats['from_cache']}")
            report.append(f"    使用降级: {stats['fallback_used']}")
        report.append("")

        report.append("=" * 60)

        return "\n".join(report)

    def save_report(self, report: str, analysis: Dict[str, Any]):
        """保存测试报告"""
        # 创建报告目录
        report_dir = os.path.join(os.path.dirname(__file__), "..", "reports")
        os.makedirs(report_dir, exist_ok=True)

        # 保存文本报告
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = os.path.join(report_dir, f"benchmark_{timestamp}.txt")
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report)

        # 保存JSON数据
        json_file = os.path.join(report_dir, f"benchmark_{timestamp}.json")
        with open(json_file, "w", encoding="utf-8") as f:
            json.dump(analysis, f, indent=2, ensure_ascii=False)

        print(f"报告已保存:")
        print(f"  文本: {report_file}")
        print(f"  JSON: {json_file}")


async def main():
    """主函数"""
    print("=" * 60)
    print("Aurora-Roguelike-AI 性能测试")
    print("=" * 60)

    benchmark = AIBenchmark()

    # 测试1: 顺序测试
    print("\n[测试1] 顺序测试 (每个端点3次请求)...")
    sequential_results = await benchmark.run_sequential_test(requests_per_endpoint=3)
    sequential_analysis = benchmark.analyze_results(sequential_results)
    sequential_report = benchmark.generate_report(sequential_analysis)
    print(sequential_report)

    # 测试2: 并发测试
    print("\n[测试2] 并发测试 (并发数=5, 每个端点5次请求)...")
    concurrent_results = await benchmark.run_concurrent_test(concurrency=5, requests_per_endpoint=5)
    concurrent_analysis = benchmark.analyze_results(concurrent_results)
    concurrent_report = benchmark.generate_report(concurrent_analysis)
    print(concurrent_report)

    # 保存报告
    benchmark.save_report(sequential_report, sequential_analysis)
    benchmark.save_report(concurrent_report, concurrent_analysis)

    print("\n测试完成!")


if __name__ == "__main__":
    asyncio.run(main())
