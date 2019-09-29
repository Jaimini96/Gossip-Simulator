defmodule  Service do

  use GenServer

  def main(args) do
    [numberOfNodes_, topology, algorithm] = args
    {numberOfNodes,_} = Integer.parse(numberOfNodes_)
    percentage = 0
    main_(numberOfNodes, topology, algorithm, percentage)

  end

  def init(size) do
    {:ok, [1,[],[],[{1,1}],[{1,1}],0,0,size,1,0,[],[] ]}
    #[cast_number, nodes_recieved, nodes_hibernated, prev_droid, prev_to_prev_droid, recieve_count, hibernation_count]
  end

  def main(numberOfNodes, topology, algorithm, percentage \\ 0) do
    main_(numberOfNodes, topology, algorithm, percentage)
  end

  def main_(numberOfNodes, topology, algorithm, percentage) do
    size =  round(Float.ceil(:math.sqrt(numberOfNodes)))
    Service.supervise(size)
    case algorithm do
      "gossip" ->
        case topology do
        "line"   -> Line.create_network(numberOfNodes, 0)
                    # deactivate(percentage)
                    GenServer.cast(Line.droid_name(round(1)),{:message_gossip, :_sending})
        "grid"   -> Grid.create_network(size,false, 0)
                    #deactivate(percentage)
                    GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
        # "i_grid" -> Grid.create_network(size,true, 0)
        #             deactivate(percentage)
        #             GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_gossip, :_sending})
        # "full"   -> Full.create_network(numNodes, 0)
        #             deactivate(percentage)
        #             GenServer.cast(Full.droid_name(round(numNodes/2)),{:message_gossip, :_sending})
        end
      "pushsum" ->
        case topology do
          "line"   -> Line.create_network(numberOfNodes, 1)
                      # deactivate(percentage)
                      GenServer.cast(Line.droid_name(round(numberOfNodes/2)),{:message_push_sum, { 0, 0}})
          # "grid"   -> Grid.create_network(size,false, 1)
          #             deactivate(percentage)
          #             GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          # "i_grid" -> Grid.create_network(size,true, 1)
          #             deactivate(percentage)
          #             GenServer.cast(Grid.droid_name(round(size/2),round(size/2)),{:message_push_sum, { 0, 0}})
          # "full"   -> Full.create_network(numNodes, 1)
          #             deactivate(percentage)
          #             GenServer.cast(Full.droid_name(round(numNodes/2)),{:message_push_sum, { 0, 0}})
        end
    end
    Process.sleep(:infinity)
  end

  def supervise(size) do
    GenServer.start_link(Service,size, name: Master)
  end

  # NETWORK - update state with the active droids
  def handle_cast({:droids_update, droids_update }, [_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,_size, _draw_every,_init_time, droids, dead_droids]) do
    {:noreply,[_cast_num,_received, _hibernated,_prev_droid, _prev_droid_2, _r_count, _h_count,_size,_draw_every,_init_time,droids_update,dead_droids]}
  end

  def handle_cast({:received, droid }, [cast_num,received, hibernated, prev_droid, prev_droid_2,r_count, h_count,size, draw_every,init_time,_droids ,dead_droids]) do
    init_time_ =
      case cast_num do
        1 -> DateTime.utc_now()
        _ -> init_time
      end

    {:noreply,[cast_num+1,received ++ droid, hibernated, droid, prev_droid, r_count + 1,h_count,size,draw_every, init_time_,_droids, dead_droids]}

  end

  # HANDLE FAILURE - updating the messages that received the message
  def handle_cast({:hibernated, droid }, [cast_num,received, hibernated,prev_droid, prev_droid_2, r_count, h_count,size, draw_every,init_time, droids,dead_droids]) do
    end_time = DateTime.utc_now
    convergence_time=DateTime.diff(end_time,init_time,:millisecond)
    IO.puts("Convergence time: #{convergence_time} ms")
    :init.stop
    {:noreply,[cast_num+1,received, hibernated ++ droid,droid, prev_droid, r_count, h_count + 1,size,draw_every,init_time,droids,dead_droids]}
  end

end
