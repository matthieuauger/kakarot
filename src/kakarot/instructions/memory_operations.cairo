// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.math_cmp import is_le, is_le_felt
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem
from starkware.cairo.common.alloc import alloc

from kakarot.model import model
from utils.utils import Helpers
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.execution_context import ExecutionContext
from kakarot.constants import Constants
from kakarot.interfaces.interfaces import IEvm_Contract

// @title Exchange operations opcodes.
// @notice This file contains the functions to execute for memory operations opcodes.
// @author @LucasLvy @abdelhamidbakhta
// @custom:namespace MemoryOperations
namespace MemoryOperations {
    const GAS_COST_MLOAD = 3;
    const GAS_COST_MSTORE = 3;
    const GAS_COST_PC = 2;
    const GAS_COST_MSIZE = 2;
    const GAS_COST_JUMP = 8;
    const GAS_COST_JUMPI = 10;
    const GAS_COST_JUMPDEST = 1;
    const GAS_COST_POP = 2;
    const GAS_COST_MSTORE8 = 3;
    const GAS_COST_SSTORE = 100;
    const GAS_COST_SLOAD = 100;
    const GAS_COST_GAS = 2;

    // @notice MLOAD operation
    // @dev Load word from memory and push to stack.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_mload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x51 - MLOAD")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the word we read.
        let (stack, offset) = Stack.pop(stack);

        // Read word from memory at offset
        let (new_memory, cost) = Memory.insure_length(self=ctx.memory, length=32 + offset.low);

        let value = Memory.load(self=new_memory, offset=offset.low);

        // Push word to the stack
        let stack: model.Stack* = Stack.push(stack, value);

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, new_memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MLOAD + cost);

        return ctx;
    }

    // @notice MSTORE operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_mstore{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x52 - MSTORE")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - value: value to store in memory.
        let (stack, offset) = Stack.pop(stack);
        let (stack, value) = Stack.pop(stack);

        let memory: model.Memory* = Memory.store(self=ctx.memory, element=value, offset=offset.low);

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSTORE);
        return ctx;
    }

    // @notice PC operation
    // @dev Get the value of the program counter prior to the increment.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_pc{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x58 - PC")
        %}
        let pc = Helpers.to_uint256(ctx.program_counter - 1);

        let stack: model.Stack* = Stack.push(ctx.stack, pc);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_PC);
        return ctx;
    }

    // @notice MSIZE operation
    // @dev Get the value of memory size.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_msize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info ("0x59 - MSIZE")
        %}
        let len = ctx.memory.bytes_len;
        let msize = Helpers.to_uint256(len);

        let stack: model.Stack* = Stack.push(ctx.stack, msize);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSIZE);
        return ctx;
    }

    // @notice JUMP operation
    // @dev The JUMP instruction changes the pc counter. The new pc target has to be a JUMPDEST opcode.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 8
    // @custom:stack_consumed_elements 1
    // @return Updated execution context.
    func exec_jump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x56 - JUMP")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: offset in the deployed code where execution will continue from
        let (stack, offset) = Stack.pop(stack);

        // Update pc counter.
        ExecutionContext.update_program_counter(ctx, offset.low);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMP);
        return ctx;
    }

    // @notice JUMPI operation
    // @dev Change the pc counter under a provided certain condition.
    //      The new pc target has to be a JUMPDEST opcode.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 10
    // @custom:stack_consumed_elements 2
    // @return Updated execution context.
    func exec_jumpi{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x57 - JUMPI")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: offset in the deployed code where execution will continue from
        // 1 - skip_jump: condition that will trigger a jump if not FALSE
        let (stack, offset) = Stack.pop(stack);
        let (stack, skip_condition) = Stack.pop(stack);

        // Update pc if skip_jump is anything other then 0
        if (skip_condition.low == 1) {
            // Update pc counter.
            let ctx = ExecutionContext.update_program_counter(ctx, offset.low);
            // Update context stack.
            let ctx = ExecutionContext.update_stack(ctx, stack);
            // Increment gas used.
            let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMPI);
            return ctx;
        }

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMPI);
        return ctx;
    }

    // @notice JUMPDEST operation
    // @dev Set this pc as Jumpdestination and improve Program Counter by one.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_jumpdest{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{
            import logging
            logging.info("0x5b - JUMPDEST")
        %}
        alloc_locals;
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMPDEST);

        return ctx;
    }

    // @notice POP operation
    // @dev Pops the first item on the stack (top of the stack).
    // @custom: since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_pop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x50 - POP")
        %}

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        let (stack, _) = Stack.pop(stack);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_POP);
        return ctx;
    }

    // @notice MSTORE8 operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_mstore8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x53 - MSTORE8")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - value: value from which the last byte will be extracted and stored in memory.
        let (stack, offset) = Stack.pop(stack);
        let (stack, value) = Stack.pop(stack);
        let (quotient, remainder) = uint256_unsigned_div_rem(value, Uint256(256, 0));

        let (value_pointer: felt*) = alloc();
        assert [value_pointer] = remainder.low;

        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=1, element=value_pointer, offset=offset.low
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSTORE8);
        return ctx;
    }

    // @notice SSTORE operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_sstore{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x55 - SSTORE")
        %}

        let stack = ctx.stack;

        // ------- 1. Get starknet address
        let starknet_address: felt = ctx.starknet_address;

        // ----- 2. Pop 2 values: key and value

        // Stack input:
        // 0 - key: key of memory.
        // 1 - value: value for given key.
        let (stack, local key) = Stack.pop(stack);
        let (stack, local value) = Stack.pop(stack);

        // 3. Call Write storage on contract with starknet address

        with_attr error_message("Contract call failed") {
            IEvm_Contract.write_state(contract_address=starknet_address, key=key, value=value);
        }

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SSTORE);
        return ctx;
    }

    // @notice SLOAD operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_sload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let stack = ctx.stack;

        // ------- 1. Get starknet address
        let starknet_address: felt = ctx.starknet_address;

        // ----- 2. Pop 2 values: key and value

        // Stack input:
        // 0 - key: key of memory.
        // 1 - value: value for given key.
        let (stack, local key) = Stack.pop(stack);
        // local value: Uint256;
        // 3. Get the data and add on the Stack

        let (local value: Uint256) = IEvm_Contract.state(
            contract_address=starknet_address, key=key
        );

        let stack: model.Stack* = Stack.push(stack, value);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SLOAD);
        return ctx;
    }

    // @notice GAS operation
    // @dev Get the amount of available gas, including the corresponding reduction for the cost of this instruction.
    // @custom: since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_gas{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x5A - GAS")
        %}

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Compute remaining gas.
        let remaining_gas = ctx.gas_limit - ctx.gas_used - GAS_COST_GAS;
        let stack: model.Stack* = Stack.push(ctx.stack, Uint256(remaining_gas, 0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_GAS);
        return ctx;
    }
}
