defmodule Full do

  use GenServer


  # DECISION:  GOSSIP vs PUSH_SUM
  def init([x,n, is_push_sum]) do
    case is_push_sum do
      0 -> {:ok, [Active,0,0, n, x ] } #[ rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, n, x] } #[ rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

    # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,n,x ] =state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    case count < 100 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,self(),n,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,n, x  ]}
  end

  # GOSSIP  - SEND Main
  def gossip(x,pid, n,i,j) do
    the_one = selected_neighbor(n)
    case the_one == node_name(x) do
      true -> gossip(x,pid, n,i,j)
      false ->
        GenServer.cast(the_one, {:message_gossip, :_sending})
        # ina_xy -> GenServer.cast(Master,{:neighbors_inactive, ina_xy})
        #gossip(x,pid, n,i,j)
        # case GenServer.call(the_one,:is_active) do
        #   Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
        #             ina_xy -> GenServer.cast(Master,{:neighbors_inactive, ina_xy})
        #             gossip(x,pid, n,i,j)
        # end
      end
  end

      # PUSHSUM - RECIEVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x | neighbors ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum(x,(s+rec_s)/2,(w+rec_w)/2,n,self(),i,j)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x  | neighbors]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x  | neighbors]}
            false -> push_sum(x,(s+rec_s)/2, (w+rec_w)/2, n, self(), i, j)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x  | neighbors]}
          end
      end
  end

  # PUSHSUM  - SEND MAIN
  def push_sum(x,s,w,n,pid ,i,j) do
    the_one = selected_neighbor(n)
    GenServer.cast(the_one,{:message_push_sum,{ s,w}})
    # case GenServer.call(the_one,:is_active) do
    #   Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
    #   ina_xy ->  GenServer.cast(Master,{:node_inactive, ina_xy})
    #             new_neighbor = GenServer.call(Master,:handle_node_failure)
    #             GenServer.cast(self(),{:remove_neighbor,the_one})
    #             GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
    #             GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x)})
    #             GenServer.cast(self(),{:retry_push_sum,{x,s,w,pid,i,j}})
    # end
  end

    # NETWORK : Creating Network
  def create_topology(n, is_push_sum \\ 0) do
    all_nodes =
      for x <- 1..n do
        name = node_name(x)
        GenServer.start_link(Full, [x,n,is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:all_nodes_update,all_nodes})
  end

  # NETWORK : Naming the node
  def node_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  # NETWORK : Defining and assigning Neighbors
  # ~ Not required as all are neighbors

  # NETWORK : Choosing a neigbor randomly to send message to
  def selected_neighbor(n) do
    :rand.uniform(n)
    |> node_name()
  end

end
