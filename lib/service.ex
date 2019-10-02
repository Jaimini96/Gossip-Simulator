defmodule  Service do

  use GenServer

  def main(args) do
    if length(args) == 3 do
      [numberOfNodes_, topology, algorithm] = args
      {numberOfNodes,_} = Integer.parse(numberOfNodes_)
      percentage = 0
      main_(numberOfNodes, topology, algorithm, percentage)
    end
    if length(args) == 4 do
      [numberOfNodes_, topology, algorithm, percentage_ ] = args
      {numberOfNodes,_} = Integer.parse(numberOfNodes_)
      {percentage,_} = Integer.parse(percentage_)
      main_(numberOfNodes, topology, algorithm, percentage)
    end


  end

  def init(size) do
    {:ok, [1,[],[],[{1,1}],[{1,1}],0,0,size,1,0,[],[] ]}
    #[cast_number, nodes_recieved, nodes_hibernated, prev_node, prev_to_prev_node, recieve_count, hibernation_count]
  end

  def main(numberOfNodes, topology, algorithm, percentage \\ 0) do
    main_(numberOfNodes, topology, algorithm, percentage)
  end

  def main_(numberOfNodes, topology, algorithm, percentage) do

    cubeRoot = round(Float.ceil(:math.pow(numberOfNodes, 1/3)))
    size =  round(Float.ceil(:math.sqrt(numberOfNodes)))
    Service.supervise(size)
    case algorithm do
      "gossip" ->
        case topology do
        "line"   -> Line.create_topology(numberOfNodes, 0)
                    fail_forcefully(percentage)
                    GenServer.cast(Line.node_name(round(1)),{:message_gossip, :_sending})
        "rand2D"   -> Rand2d.create_topology(size,false, 0)
                    fail_forcefully(percentage)
                    GenServer.cast(Rand2d.node_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
        "3Dtorus"   -> Torus3d.create_topology(cubeRoot,false, 0)
                    fail_forcefully(percentage)
                    GenServer.cast(Torus3d.node_name(round(cubeRoot/2),round(cubeRoot/2),round(cubeRoot/2)),{:message_gossip, :_sending})
        "honeycomb" -> Honeycomb.create_topology(round(size*size), 0)
                    fail_forcefully(percentage)
                    GenServer.cast(Honeycomb.node_name(round(size)),{:message_gossip, :_sending})
        "randhoneycomb" -> Randhoneycomb.create_topology(round(size*size), 0)
                    fail_forcefully(percentage)
                    GenServer.cast(Randhoneycomb.node_name(round(1)),{:message_gossip, :_sending})
        "full"   -> Full.create_topology(numberOfNodes, 0)
                    fail_forcefully(percentage)
                    GenServer.cast(Full.node_name(round(numberOfNodes/2)),{:message_gossip, :_sending})
        end
      "pushsum" ->
        case topology do
          "line"   -> Line.create_topology(numberOfNodes, 1)
                      fail_forcefully(percentage)
                      GenServer.cast(Line.node_name(round(numberOfNodes/2)),{:message_push_sum, { 0, 0}})
          "rand2D"   -> Rand2d.create_topology(size,false, 1)
                      fail_forcefully(percentage)
                      GenServer.cast(Rand2d.node_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          "3Dtorus"   -> Torus3d.create_topology(cubeRoot,false, 1)
                      fail_forcefully(percentage)
                      GenServer.cast(Torus3d.node_name(round(cubeRoot/2),round(cubeRoot/2),round(cubeRoot/2)),{:message_push_sum, {0,0}})
          "full"   -> Full.create_topology(numberOfNodes, 1)
                      fail_forcefully(percentage)
                      GenServer.cast(Full.node_name(round(numberOfNodes/2)),{:message_push_sum, { 0, 0}})
          "honeycomb" -> Honeycomb.create_topology(round(size*size), 1)
                      fail_forcefully(percentage)
                      GenServer.cast(Honeycomb.node_name(round(1)),{:message_push_sum, { 0, 0}})
          "randhoneycomb" -> Randhoneycomb.create_topology(round(size*size), 1)
                      fail_forcefully(percentage)
                      GenServer.cast(Randhoneycomb.node_name(round(1)),{:message_push_sum, { 0, 0}})
        end
    end
    Process.sleep(:infinity)
  end

  def fail_forcefully(prcnt) do
    if prcnt == 0 do
      ""
    else GenServer.cast(Master, {:goto_sleep, prcnt})
    end
  end

  def handle_cast({:goto_sleep, prcnt }, [_cast_num,_received, _hibernated,_prev_node, _prev_node_2, _r_count, _h_count,size, _draw_every,_init_time, nodes, dead_nodes]) do
    sleeping_nodes_count = round(size*size*prcnt / 100)
    sleeping_nodes = Enum.take_random(nodes,sleeping_nodes_count)
    IO.puts("Forcefully Failed nodes: #{inspect sleeping_nodes} ")
    Enum.each sleeping_nodes, fn( node ) ->
      GenServer.cast(node,{:goto_sleep, :going_to_sleep })
    end
    {:noreply,[_cast_num,_received, _hibernated,_prev_node, _prev_node_2, _r_count, _h_count,size,_draw_every,_init_time,nodes, dead_nodes]}
  end

  def supervise(size) do
    GenServer.start_link(Service,size, name: Master)
  end

  # NETWORK - update state with the active all_nodes
  def handle_cast({:all_nodes_update, all_nodes_update }, [_cast_num,_received, _hibernated,_prev_node, _prev_node_2, _r_count, _h_count,_size, _draw_every,_init_time, all_nodes, dead_all_nodes]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_node, _prev_node_2, _r_count, _h_count,_size,_draw_every,_init_time,all_nodes_update,dead_all_nodes]}
  end

  def handle_cast({:neighbors_inactive, node },[_cast_num,_received, _hibernated,_prev_node, _prev_node_2, _r_count, _h_count,_size, _draw_every,_init_time, nodes,dead_nodes]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_node, _prev_node_2, _r_count, _h_count,_size,_draw_every,_init_time,List.delete(nodes,node),dead_nodes ++ node]}
  end

  def handle_call(:handle_node_failure, {pid,_} ,[_cast_num,_received, _hibernated,_prev_node, _prev_node_2, _r_count, _h_count,_size, _draw_every,_init_time, nodes,dead_nodes]) do
    new_node = Enum.random(nodes)
    new_node = case :erlang.whereis(new_node) do
      ^pid -> List.delete(nodes,new_node)
              Enum.random(nodes)
      _ -> new_node
    end
    {:reply,new_node,[_cast_num,_received, _hibernated,_prev_node, _prev_node_2, _r_count, _h_count,_size,_draw_every,_init_time,nodes,dead_nodes]}
  end

  def handle_cast({:received, node }, [cast_num,received, hibernated, prev_node, prev_node_2,r_count, h_count,size, draw_every,init_time,_all_nodes ,dead_all_nodes]) do
    init_time_ =
      case cast_num do
        1 -> DateTime.utc_now()
        _ -> init_time
      end

    {:noreply,[cast_num+1,received ++ node, hibernated, node, prev_node, r_count + 1,h_count,size,draw_every, init_time_,_all_nodes, dead_all_nodes]}

  end

  # HANDLE FAILURE - updating the messages that received the message
  def handle_cast({:hibernated, node }, [cast_num,received, hibernated,prev_node, prev_node_2, r_count, h_count,size, draw_every,init_time, all_nodes,dead_all_nodes]) do
    end_time = DateTime.utc_now
    convergence_time=DateTime.diff(end_time,init_time,:millisecond)
    IO.puts("Convergence time: #{convergence_time} ms")
    :init.stop
    {:noreply,[cast_num+1,received, hibernated ++ node,node, prev_node, r_count, h_count + 1,size,draw_every,init_time,all_nodes,dead_all_nodes]}
  end

end
