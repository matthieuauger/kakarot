from asyncio import run
from unittest import IsolatedAsyncioTestCase

from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet


class TestBlockInformation(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.starknet.state.state.update_block_info(
                BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
            )
            cls.test_enviromental_information = await cls.starknet.deploy(
                source="./tests/cairo_files/instructions/test_environmental_information.cairo",
                cairo_path=["src"],
                disable_hint_validation=True,
            )

        run(_setUpClass(cls))

    async def coverageSetupClass(cls):
        cls.test_enviromental_information = await cls.starknet.deploy(
            source="./tests/cairo_files/instructions/test_environmental_information.cairo",
            cairo_path=["src"],
            disable_hint_validation=True,
        )

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={"site-packages"})

    async def test_everything_environmental(self):
        await self.test_enviromental_information.test__exec_address__should_push_address_to_stack().call()
